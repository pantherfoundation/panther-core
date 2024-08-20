// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { Providers, FeeParams, FeeData, AssetData, ChargedFeesPerTx } from "./Types.sol";

import "../../../common/UtilsLib.sol";
import { HUNDRED_PERCENT, NATIVE_TOKEN } from "../../../common/Constants.sol";

abstract contract FeeAccountant {
    using UtilsLib for uint256;
    using UtilsLib for uint96;
    using UtilsLib for uint40;
    using UtilsLib for uint32;

    address public immutable PANTHER_POOL;
    address public immutable PANTHER_BUS_TREE;
    address public immutable PAYMASTER;
    address public immutable TRUST_PROVIDER;
    address public immutable ZKP_TOKEN;

    FeeParams public feeParams;

    // provider => token => amounts
    mapping(address => mapping(address => uint256)) public debts;

    event DebtsUpdated(address provider, address token, uint256 updatedDebt);

    constructor(Providers memory provider, address zkpToken) {
        PANTHER_POOL = provider.pantherPool;
        PANTHER_BUS_TREE = provider.pantherBusTree;
        PAYMASTER = provider.paymaster;
        TRUST_PROVIDER = provider.trustProvider;
        ZKP_TOKEN = zkpToken;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getDebtForProtocol(address token) public view returns (uint256) {
        return debts[PANTHER_POOL][token];
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _updateDebtForProtocol(address token, int256 netAmount) internal {
        uint256 protocolDebts = debts[PANTHER_POOL][token];

        if (netAmount > 0) {
            protocolDebts += uint256(netAmount);
        }
        if (netAmount < 0) {
            protocolDebts -= uint256(-netAmount);
        }

        debts[PANTHER_POOL][token] = protocolDebts;
    }

    function _updateFeeParams(
        uint96 perUtxoReward,
        uint96 perKytFee,
        uint96 kycFee,
        uint16 protocolFeePercentage
    ) internal returns (FeeParams memory _feeParams) {
        require(perUtxoReward > 0, "Zero per utxo reward");
        require(perKytFee > 0, "Zero per kyt fee");
        require(kycFee > 0, "Zero kyc fee");
        require(
            protocolFeePercentage > 0 &&
                protocolFeePercentage < HUNDRED_PERCENT,
            "Invalid protocol fee percentage"
        );

        _feeParams = FeeParams({
            scPerUtxoReward: perUtxoReward.scaleDownBy1e12().safe32(),
            scPerKytFee: perKytFee.scaleDownBy1e12().safe32(),
            scKycFee: kycFee.scaleDownBy1e12().safe32(),
            protocolFeePercentage: protocolFeePercentage
        });

        feeParams = _feeParams;
    }

    function _accountActivationFees(
        FeeData calldata feeData
    ) internal returns (ChargedFeesPerTx memory chargedFeesPerTx) {
        FeeParams memory _feeParams = feeParams;

        // Unscale the parameters
        uint256 kycFee = _feeParams.scKycFee.scaleUpBy1e12();
        uint256 perUtxoReward = _feeParams.scPerUtxoReward.scaleUpBy1e12();
        uint256 paymasterZkpFee = feeData.scPaymasterZkpFee.scaleUpBy1e12();
        uint256 chargedZkpAmount = feeData.scChargedZkpAmount.scaleUpBy1e12();

        uint256 paymasterCompensationInNative = _accountDebtForPaymaster(
            paymasterZkpFee
        );
        _accountKycFees(kycFee);

        uint256 paymasterAndKycFees = paymasterZkpFee + kycFee;

        uint256 miningReward = _accountDebtForBusTree(
            perUtxoReward,
            feeData.numOutputUtxos,
            paymasterAndKycFees,
            chargedZkpAmount
        );

        chargedFeesPerTx = ChargedFeesPerTx({
            scMiningReward: miningReward.scaleDownBy1e12().safe40(),
            scKycFee: _feeParams.scKycFee,
            scPaymasterCompensationInNative: paymasterCompensationInNative
                .scaleDownBy1e12()
                .safe40(),
            scKytFees: 0,
            protocolFee: 0
        });
    }

    function _accountPrpConversionOrClaimFees(
        FeeData calldata feeData
    ) internal returns (ChargedFeesPerTx memory chargedFeesPerTx) {
        FeeParams memory _feeParams = feeParams;

        uint256 perUtxoReward = _feeParams.scPerUtxoReward.scaleUpBy1e12();
        uint256 paymasterZkpFee = feeData.scPaymasterZkpFee.scaleUpBy1e12();
        uint256 chargedZkpAmount = feeData.scChargedZkpAmount.scaleUpBy1e12();

        uint256 paymasterCompensationInNative = _accountDebtForPaymaster(
            paymasterZkpFee
        );

        uint256 miningReward = _accountDebtForBusTree(
            perUtxoReward,
            feeData.numOutputUtxos,
            paymasterZkpFee,
            chargedZkpAmount
        );

        chargedFeesPerTx = ChargedFeesPerTx({
            scMiningReward: miningReward.scaleDownBy1e12().safe40(),
            scPaymasterCompensationInNative: paymasterCompensationInNative
                .scaleDownBy1e12()
                .safe40(),
            scKycFee: 0,
            scKytFees: 0,
            protocolFee: 0
        });
    }

    function _accountMainFees(
        FeeData calldata feeData,
        AssetData calldata assetData
    ) internal returns (ChargedFeesPerTx memory chargedFeesPerTx) {
        FeeParams memory _feeParams = feeParams;

        uint256 perKytFee = _feeParams.scPerKytFee.scaleUpBy1e12();
        uint256 perUtxoReward = _feeParams.scPerUtxoReward.scaleUpBy1e12();
        uint256 paymasterZkpFee = feeData.scPaymasterZkpFee.scaleUpBy1e12();
        uint256 chargedZkpAmount = feeData.scChargedZkpAmount.scaleUpBy1e12();

        uint256 paymasterCompensationInNative = _accountDebtForPaymaster(
            paymasterZkpFee
        );
        uint256 kytFees = _accountKytFees(
            perKytFee,
            assetData.depositAmount,
            assetData.withdrawAmount
        );

        uint256 paymasterAndKytFees = paymasterZkpFee + kytFees;
        uint256 miningReward = _accountDebtForBusTree(
            perUtxoReward,
            feeData.numOutputUtxos,
            paymasterAndKytFees,
            chargedZkpAmount
        );

        uint256 protocolFee = _accountDebtForProtocol(
            _feeParams.protocolFeePercentage,
            assetData.withdrawAmount,
            assetData.tokenAddress
        );

        chargedFeesPerTx = ChargedFeesPerTx({
            scMiningReward: miningReward.scaleDownBy1e12().safe40(),
            scKytFees: kytFees.scaleDownBy1e12().safe40(),
            protocolFee: protocolFee.safe96(),
            scPaymasterCompensationInNative: paymasterCompensationInNative
                .scaleDownBy1e12()
                .safe40(),
            scKycFee: 0
        });
    }

    function _accountZSwap(
        FeeData calldata feeData
    ) internal returns (ChargedFeesPerTx memory chargedFeesPerTx) {
        FeeParams memory _feeParams = feeParams;

        uint256 perUtxoReward = _feeParams.scPerUtxoReward.scaleUpBy1e12();
        uint256 paymasterZkpFee = feeData.scPaymasterZkpFee.scaleUpBy1e12();
        uint256 chargedZkpAmount = feeData.scChargedZkpAmount.scaleUpBy1e12();

        uint256 paymasterCompensationInNative = _accountDebtForPaymaster(
            paymasterZkpFee
        );

        uint256 miningReward = _accountDebtForBusTree(
            perUtxoReward,
            feeData.numOutputUtxos,
            paymasterZkpFee,
            chargedZkpAmount
        );

        chargedFeesPerTx = ChargedFeesPerTx({
            scMiningReward: miningReward.scaleDownBy1e12().safe40(),
            scPaymasterCompensationInNative: paymasterCompensationInNative
                .scaleDownBy1e12()
                .safe40(),
            protocolFee: 0,
            scKytFees: 0,
            scKycFee: 0
        });
    }

    function _accountDebtForPaymaster(
        uint256 paymasterCompensationInZkp
    ) internal returns (uint256 paymasterFeeInNative) {
        if (paymasterCompensationInZkp == 0) return paymasterFeeInNative;

        (
            uint256 paymasterDebtInZkp,
            uint256 paymasterDebtInNative
        ) = _tryInternalZkpToNativeConversion(paymasterCompensationInZkp);

        if (paymasterDebtInZkp > 0) {
            _updateDebts(PAYMASTER, ZKP_TOKEN, int256(paymasterDebtInZkp));
        }

        if (paymasterDebtInNative > 0) {
            _updateDebts(
                PAYMASTER,
                NATIVE_TOKEN,
                int256(paymasterDebtInNative)
            );
        }
    }

    function _accountKytFees(
        uint256 perKytFee,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) private returns (uint256 kytFees) {
        if (depositAmount > 0) {
            kytFees += perKytFee;
        }

        if (withdrawAmount > 0) {
            kytFees += perKytFee;
        }

        _updateDebts(TRUST_PROVIDER, ZKP_TOKEN, int256(kytFees));
    }

    function _accountKycFees(uint256 kycFee) private {
        _updateDebts(TRUST_PROVIDER, ZKP_TOKEN, int256(kycFee));
    }

    function _accountDebtForBusTree(
        uint256 perUtxoReward,
        uint256 numberOfUtxos,
        uint256 allocatedZkpFees,
        uint256 totalChargedFees
    ) private returns (uint256 miningReward) {
        require(perUtxoReward > 0, "zero reward per utxo");
        require(numberOfUtxos > 0, "zero unmber of utxos");

        uint256 minimumBusTreeFee = numberOfUtxos * perUtxoReward;
        miningReward = totalChargedFees - allocatedZkpFees;
        require(
            miningReward >= minimumBusTreeFee,
            "insufficient mining rewards"
        );

        _updateDebts(PANTHER_BUS_TREE, ZKP_TOKEN, int256(miningReward));
    }

    function _accountDebtForProtocol(
        uint256 protocolFeePercentage,
        uint256 withdrawAmount,
        address tokenAddress
    ) private returns (uint256 protocolFee) {
        protocolFee =
            (withdrawAmount * protocolFeePercentage) /
            HUNDRED_PERCENT;

        _updateDebts(PANTHER_POOL, tokenAddress, int256(protocolFee));
    }

    function _updateDebts(
        address provider,
        address token,
        int256 amountSpecified
    ) internal {
        uint256 debtBefore = debts[provider][token];

        uint256 debtAfter = amountSpecified < 0
            ? debtBefore - uint256(-amountSpecified)
            : debtBefore + uint256(amountSpecified);

        debts[provider][token] = debtAfter;

        emit DebtsUpdated(provider, token, debtAfter);
    }

    function _tryInternalZkpToNativeConversion(
        uint256 paymasterCompensationInZkp
    )
        internal
        virtual
        returns (uint256 paymasterDebtInZkp, uint256 paymasterDebtInNative);
}
