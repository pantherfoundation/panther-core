// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IVaultV1.sol";
import "../interfaces/IFeeMaster.sol";

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

abstract contract TransactionChargesHandler {
    using TransactionTypes for uint16;
    using UtilsLib for uint256;
    using UtilsLib for uint96;
    using UtilsLib for uint40;

    mapping(address => uint256) public feeMasterDebt;

    address public immutable ZKP_TOKEN;
    address public immutable FEE_MASTER;
    address public immutable VAULT;

    event FeesAccounted(ChargedFeesPerTx chargedFeesPerTx);

    constructor(address zkpToken, address feeMaster, address vault) {
        ZKP_TOKEN = zkpToken;
        FEE_MASTER = feeMaster;
        VAULT = vault;
    }

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

        if (txType == TT_ZSWAP) {
            numOutputUtxos = 5;

            scAddedZkpAmount = inputs[ZSWAP_ADDED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();
            scChargedZkpAmount = inputs[ZSWAP_CHARGED_AMOUNT_ZKP_IND]
                .scaleDownBy1e12()
                .safe40();

            // TODO: change the deposit and withdraw amounts
            assetData = AssetData({
                tokenAddress: address(inputs[ZSWAP_TOKEN_IN_IND].safe160()),
                depositAmount: inputs[ZSWAP_DEPOSIT_AMOUNT_IND].safe128(),
                withdrawAmount: inputs[ZSWAP_WITHDRAW_AMOUNT_IND].safe128()
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

    function _lockAssetAndIncreaseFeeMasterDebt(LockData memory data) private {
        address token = data.token;

        feeMasterDebt[token] += data.extAmount;
        uint256 msgValue = token == NATIVE_TOKEN ? msg.value : 0;

        IVaultV1(VAULT).lockAsset{ value: msgValue }(data);
    }

    function _unlockAssetAndDecreaseFeeMasterDebt(
        LockData memory data
    ) private {
        feeMasterDebt[data.token] -= data.extAmount;

        IVaultV1(VAULT).unlockAsset(data);
    }

    function _increaseFeeMasterDebt(address token, uint256 amount) private {
        feeMasterDebt[token] += amount;
    }

    function _accountFees(
        FeeData memory feeData
    ) private returns (ChargedFeesPerTx memory) {
        try IFeeMaster(FEE_MASTER).accountFees(feeData) returns (
            ChargedFeesPerTx memory chargedFeesPerTx
        ) {
            return chargedFeesPerTx;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _accountFees(
        FeeData memory feeData,
        AssetData memory assetData
    ) private returns (ChargedFeesPerTx memory) {
        try IFeeMaster(FEE_MASTER).accountFees(feeData, assetData) returns (
            ChargedFeesPerTx memory chargedFeesPerTx
        ) {
            return chargedFeesPerTx;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}
