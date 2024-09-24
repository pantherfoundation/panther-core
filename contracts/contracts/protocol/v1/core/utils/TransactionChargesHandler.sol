// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../interfaces/IVaultV1.sol";
import "../../interfaces/IFeeAccountant.sol";

import "./Types.sol";
import "../publicSignals/MainPublicSignals.sol";
import "../publicSignals/ZAccountActivationPublicSignals.sol";
import "../publicSignals/PrpAccountingPublicSignals.sol";
import "../publicSignals/PrpConversionPublicSignals.sol";
import "../publicSignals/ZSwapPublicSignals.sol";
import "../../../../common/UtilsLib.sol";
import "../libraries/TransactionTypes.sol";
import "../libraries/TokenTypeAndAddressDecoder.sol";

/**
 * @title TransactionChargesHandler
 * @notice Provides methods for adjusting vault assets, accounting fees,
 * and handling various transaction types with specific fee calculations.
 */
abstract contract TransactionChargesHandler {
    using TokenTypeAndAddressDecoder for uint256;
    using TransactionTypes for uint16;
    using UtilsLib for uint256;
    using UtilsLib for uint96;
    using UtilsLib for uint40;

    // Immutable state variables
    address internal immutable ZKP_TOKEN;
    address internal immutable FEE_MASTER;

    event FeesAccounted(ChargedFeesPerTx chargedFeesPerTx);

    /**
     * @dev Constructor sets the ZKP token and fee master contract addresses.
     * @param feeMaster Address of the fee master contract responsible for fee calculations.
     * @param zkpToken Address of ZKP token.
     */
    constructor(address feeMaster, address zkpToken) {
        require(
            feeMaster != address(0) && zkpToken != address(0),
            "init::TransactionChargesHandler:zero address"
        );

        FEE_MASTER = feeMaster;
        ZKP_TOKEN = zkpToken;
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
        mapping(address => uint256) storage feeMasterDebt,
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

            (, address tokenAddress) = inputs[MAIN_TOKEN_IND]
                .getTokenTypeAndAddress();

            assetData = AssetData({
                tokenAddress: tokenAddress,
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

        _increaseFeeMasterDebt(
            feeMasterDebt,
            ZKP_TOKEN,
            inputs[MAIN_CHARGED_AMOUNT_ZKP_IND]
        );

        protocolFee = chargedFeesPerTx.protocolFee;
        if (protocolFee > 0) {
            _increaseFeeMasterDebt(
                feeMasterDebt,
                assetData.tokenAddress,
                protocolFee
            );
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
        mapping(address => uint256) storage feeMasterDebt,
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

        if (txType == TT_PRP_ACCOUNTING) {
            numOutputUtxos = 1;
            scAddedZkpAmount = inputs[PRP_ACCOUNTING_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[PRP_ACCOUNTING_CHARGED_AMOUNT_ZKP_IND]
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

        _increaseFeeMasterDebt(
            feeMasterDebt,
            ZKP_TOKEN,
            scChargedZkpAmount.scaleUpBy1e12()
        );

        miningReward = chargedFeesPerTx.scMiningReward.scaleUpBy1e12().safe96();

        emit FeesAccounted(chargedFeesPerTx);
    }

    /**
     * @dev Internal function to increase fee master debt for a specific token.
     * @param token Address of the token for which debt is increased.
     * @param amount Amount by which to increase the debt.
     */
    function _increaseFeeMasterDebt(
        mapping(address => uint256) storage feeMasterDebt,
        address token,
        uint256 amount
    ) private {
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
}
