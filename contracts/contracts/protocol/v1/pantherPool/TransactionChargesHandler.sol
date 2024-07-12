// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IVaultV1.sol";
import "../interfaces/IFeeAccountant.sol";
import "../interfaces/ITransactionChargesHandler.sol";

import "./Types.sol";
import "./publicSignals/MainPublicSignals.sol";
import "./publicSignals/ZAccountActivationPublicSignals.sol";
import "./publicSignals/PrpClaimPublicSignals.sol";
import "./publicSignals/PrpConversionPublicSignals.sol";
import "./publicSignals/ZSwapPublicSignals.sol";
import { NATIVE_TOKEN, NATIVE_TOKEN_TYPE, ERC20_TOKEN_TYPE } from "../../../common/Constants.sol";
import { LockData } from "../../../common/Types.sol";
import "../../../common/UtilsLib.sol";
import "./TransactionTypes.sol";
import "./VaultLib.sol";

/**
 * @title TransactionChargesHandler
 * @notice Provides methods for adjusting vault assets, accounting fees,
 * and handling various transaction types with specific fee calculations.
 */
abstract contract TransactionChargesHandler is ITransactionChargesHandler {
    using TransactionTypes for uint16;
    using VaultLib for address;
    using UtilsLib for uint256;
    using UtilsLib for uint96;
    using UtilsLib for uint40;

    mapping(address => uint256) public feeMasterDebt;

    // Immutable state variables
    address public immutable ZKP_TOKEN;
    address public immutable FEE_MASTER;

    event FeesAccounted(ChargedFeesPerTx chargedFeesPerTx);

    /**
     * @dev Constructor sets the ZKP token and fee master contract addresses.
     * @param zkpToken Address of ZKP token.
     * @param feeMaster Address of the fee master contract responsible for fee calculations.
     */
    constructor(address zkpToken, address feeMaster) {
        require(
            zkpToken != address(0) && feeMaster != address(0),
            "init::TransactionChargesHandler:zero address"
        );

        ZKP_TOKEN = zkpToken;
        FEE_MASTER = feeMaster;
    }

    /**
     * @notice Adjusts vault assets based on net amount and updates fee master debt.
     * @dev Only callable by the fee master contract.
     * @param token Address of the token being adjusted.
     * @param netAmount Net amount of tokens being locked/unlocked.
     * @param extAccount External account affected by the transaction.
     */
    function adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address token,
        int256 netAmount,
        address extAccount
    ) external payable {
        require(msg.sender == FEE_MASTER, "unauthorized");

        uint8 tokenType = token == NATIVE_TOKEN
            ? NATIVE_TOKEN_TYPE
            : ERC20_TOKEN_TYPE;

        LockData memory data = LockData({
            tokenType: tokenType,
            token: token,
            tokenId: 0,
            extAccount: extAccount,
            extAmount: netAmount > 0
                ? uint256(netAmount).safe96()
                : uint256(-netAmount).safe96()
        });

        if (netAmount > 0) {
            _lockAssetAndIncreaseFeeMasterDebt(data);
        }

        if (netAmount < 0) {
            _unlockAssetAndDecreaseFeeMasterDebt(data);
        }
    }

    /**
     * @notice Accounts fees and returns protocol fee and mining reward.
     * @dev Handles specific transaction type: Main (Deposit, Withdrawal and, Internal)
     * @param inputs Public input parameters for the transaction.
     * @param paymasterCompensation Compensation amount for the paymaster in ZKP token.
     * @param txType Type of the transaction being processed.
     * @return protocolFee The fee for protocol operations.
     * @return miningReward The reward for mining the transaction.
     */
    function accountFeesAndReturnProtocolFeeAndMiningReward(
        uint256[] calldata inputs,
        uint96 paymasterCompensation,
        uint16 txType
    ) internal returns (uint96 protocolFee, uint96 miningReward) {
        FeeData memory feeData;
        AssetData memory assetData;

        uint8 numOutputUtxos;
        uint40 scAddedZkpAmount;
        uint40 scChargedZkpAmount;

        uint40 scPaymasterZkpFee = paymasterCompensation
            .scaleDownBy1e12()
            .safe40();

        if (txType.isMain()) {
            numOutputUtxos = 5;

            scAddedZkpAmount = inputs[MAIN_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[MAIN_CHARGED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();

            assetData = AssetData({
                tokenAddress: address(inputs[MAIN_TOKEN_IND].safe160()),
                depositAmount: inputs[MAIN_DEPOSIT_AMOUNT_IND].safe128(),
                withdrawAmount: inputs[MAIN_WITHDRAW_AMOUNT_IND].safe128()
            });
        }

        feeData = FeeData({
            txType: txType,
            numOutputUtxos: numOutputUtxos,
            scPaymasterZkpFee: scPaymasterZkpFee,
            scAddedZkpAmount: scAddedZkpAmount,
            scChargedZkpAmount: scChargedZkpAmount
        });

        ChargedFeesPerTx memory chargedFeesPerTx = _accountFees(
            feeData,
            assetData
        );

        _increaseFeeMasterDebt(ZKP_TOKEN, inputs[MAIN_CHARGED_AMOUNT_ZKP_IND]);

        protocolFee = chargedFeesPerTx.protocolFee;
        if (protocolFee > 0) {
            _increaseFeeMasterDebt(assetData.tokenAddress, protocolFee);
        }

        miningReward = chargedFeesPerTx.scMiningReward.scaleUpBy1e12().safe96();

        emit FeesAccounted(chargedFeesPerTx);
    }

    /**
     * @notice Accounts fees and returns mining reward.
     * @dev Handles specific transaction types: ZAccount activation, PRP claim,
     * PRP Conversion, and zSwap.
     * @param inputs The public input parameters to be passed to verifier.
     * @param paymasterCompensation Compensation amount for the paymaster in ZKP token.
     * @param txType Type of the transaction being processed.
     * @return miningReward The reward for mining the transaction.
     */
    function accountFeesAndReturnMiningReward(
        uint256[] calldata inputs,
        uint96 paymasterCompensation,
        uint16 txType
    ) internal returns (uint96 miningReward) {
        FeeData memory feeData;

        uint8 numOutputUtxos;
        uint40 scAddedZkpAmount;
        uint40 scChargedZkpAmount;

        uint40 scPaymasterZkpFee = paymasterCompensation
            .scaleDownBy1e12()
            .safe40();

        if (txType == TT_ZACCOUNT_ACTIVATION) {
            numOutputUtxos = 2;
            scAddedZkpAmount = inputs[ZACCOUNT_ACTIVATION_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[
                ZACCOUNT_ACTIVATION_CHARGED_AMOUNT_ZKP_IND
            ].scaleDownBy1e12().safe40();
        }

        if (txType == TT_PRP_CLAIM) {
            numOutputUtxos = 1;
            scAddedZkpAmount = inputs[PRP_CLAIM_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[PRP_CLAIM_CHARGED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
        }

        if (txType == TT_PRP_CONVERSION) {
            numOutputUtxos = 2;
            scAddedZkpAmount = inputs[PRP_CONVERSION_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[PRP_CONVERSION_CHARGED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
        }

        if (txType == TT_ZSWAP) {
            numOutputUtxos = 3;

            scAddedZkpAmount = inputs[ZSWAP_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[ZSWAP_CHARGED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
        }

        feeData = FeeData({
            txType: txType,
            numOutputUtxos: numOutputUtxos,
            scPaymasterZkpFee: scPaymasterZkpFee,
            scAddedZkpAmount: scAddedZkpAmount,
            scChargedZkpAmount: scChargedZkpAmount
        });

        ChargedFeesPerTx memory chargedFeesPerTx = _accountFees(feeData);

        _increaseFeeMasterDebt(ZKP_TOKEN, scChargedZkpAmount.scaleUpBy1e12());

        miningReward = chargedFeesPerTx.scMiningReward.scaleUpBy1e12().safe96();

        emit FeesAccounted(chargedFeesPerTx);
    }

    /**
     * @dev Internal function to lock asset and increase fee master debt.
     * @param data Lock data specifying token, amount, and external account.
     */
    function _lockAssetAndIncreaseFeeMasterDebt(LockData memory data) private {
        address token = data.token;

        feeMasterDebt[token] += data.extAmount;

        _getVault().lockAsset(data);
    }

    /**
     * @dev Internal function to unlock asset and decrease fee master debt.
     * @param data Unlock data specifying token, amount, and external account.
     */
    function _unlockAssetAndDecreaseFeeMasterDebt(
        LockData memory data
    ) private {
        feeMasterDebt[data.token] -= data.extAmount;

        _getVault().unlockAsset(data);
    }

    /**
     * @dev Internal function to increase fee master debt for a specific token.
     * @param token Address of the token for which debt is increased.
     * @param amount Amount by which to increase the debt.
     */
    function _increaseFeeMasterDebt(address token, uint256 amount) private {
        feeMasterDebt[token] += amount;
    }

    /**
     * @dev Internal function to account fees based on fee data.
     * @param feeData Fee-related data including transaction type and ZKP fees.
     * @return chargedFeesPerTx Structure containing detailed fee information.
     */
    function _accountFees(
        FeeData memory feeData
    ) private returns (ChargedFeesPerTx memory) {
        try IFeeAccountant(FEE_MASTER).accountFees(feeData) returns (
            ChargedFeesPerTx memory chargedFeesPerTx
        ) {
            return chargedFeesPerTx;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    /**
     * @dev Internal function to account fees based on fee data and asset data.
     * @param feeData Fee-related data including transaction type and ZKP fees.
     * @param assetData Asset-related data including token address and amounts.
     * @return chargedFeesPerTx Structure containing detailed fee information.
     */
    function _accountFees(
        FeeData memory feeData,
        AssetData memory assetData
    ) private returns (ChargedFeesPerTx memory) {
        try IFeeAccountant(FEE_MASTER).accountFees(feeData, assetData) returns (
            ChargedFeesPerTx memory chargedFeesPerTx
        ) {
            return chargedFeesPerTx;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    /**
     * @dev Internal function to retrieve the vault address.
     * @return Address of the vault used for asset locking/unlocking operations.
     */
    function _getVault() internal view virtual returns (address);
}
