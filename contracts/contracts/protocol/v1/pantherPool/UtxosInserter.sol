// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../interfaces/IUtxoInserter.sol";

import "./TransactionOptions.sol";
import "./publicSignals/ZAccountActivationPublicSignals.sol";
import "./publicSignals/PrpClaimPublicSignals.sol";
import "./publicSignals/PrpConversionPublicSignals.sol";
import "./publicSignals/MainPublicSignals.sol";
import "./publicSignals/ZSwapPublicSignals.sol";
import { ERR_ZERO_COMITMENT } from "../errMsgs/PantherPoolV1ErrMsgs.sol";

import "../../../common/crypto/PoseidonHashers.sol";

abstract contract UtxosInserter {
    using TransactionOptions for uint32;

    address public immutable PANTHER_TREES;

    constructor(address pantherTrees) {
        require(pantherTrees != address(0), "init:zero address");

        PANTHER_TREES = pantherTrees;
    }

    function _insertZAccountActivationUtxos(
        uint256[] calldata inputs,
        uint32 transactionOptions,
        uint96 miningRewards
    )
        internal
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        bytes32 zAccountUtxoOutCommitment = bytes32(
            inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_COMMITMENT_IND]
        );
        bytes32 kycSignedMessageHash = bytes32(
            inputs[ZACCOUNT_ACTIVATION_KYC_SIGNED_MESSAGE_HASH_IND]
        );
        require(
            zAccountUtxoOutCommitment != 0 && kycSignedMessageHash != 0,
            ERR_ZERO_COMITMENT
        );

        bytes32[] memory utxos = new bytes32[](2);
        utxos[0] = zAccountUtxoOutCommitment;
        utxos[1] = kycSignedMessageHash;

        if (transactionOptions.isTaxiApplicable()) {
            // first utxo in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 1;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                utxos,
                miningRewards,
                numTaxiUtxos
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(utxos, miningRewards);
        }
    }

    function _insertPrpClaimUtxo(
        uint256[] calldata inputs,
        uint32 transactionOptions,
        uint96 miningRewards
    )
        internal
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        bytes32 zAccountUtxoOutCommitment = bytes32(
            inputs[PRP_CLAIM_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
        );
        require(zAccountUtxoOutCommitment != 0, ERR_ZERO_COMITMENT);

        bytes32[] memory utxos = new bytes32[](1);
        utxos[0] = zAccountUtxoOutCommitment;

        if (transactionOptions.isTaxiApplicable()) {
            // first utxo in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 1;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                utxos,
                miningRewards,
                numTaxiUtxos
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(utxos, miningRewards);
        }
    }

    function _insertPrpConversionUtxos(
        uint256[] calldata inputs,
        bytes32 zAssetUtxoOutCommitment,
        uint32 transactionOptions,
        uint96 miningRewards
    )
        internal
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        bytes32 zAccountUtxoOutCommitment = bytes32(
            inputs[PRP_CONVERSION_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
        );
        require(
            zAccountUtxoOutCommitment != 0 && zAssetUtxoOutCommitment != 0,
            ERR_ZERO_COMITMENT
        );

        bytes32[] memory utxos = new bytes32[](2);
        utxos[0] = zAccountUtxoOutCommitment;
        utxos[1] = zAssetUtxoOutCommitment;

        if (transactionOptions.isTaxiApplicable()) {
            // All 2 utxos in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 2;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                utxos,
                miningRewards,
                numTaxiUtxos
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(utxos, miningRewards);
        }
    }

    function _insertMainUtxos(
        uint256[] calldata inputs,
        uint32 transactionOptions,
        uint96 miningRewards
    )
        internal
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        bytes32 zAccountUtxoOutCommitment = bytes32(
            inputs[MAIN_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
        );
        bytes32 zAssetUtxoOutCommitment1 = bytes32(
            inputs[MAIN_ZASSET_UTXO_OUT_COMMITMENT_1_IND]
        );
        bytes32 zAssetUtxoOutCommitment2 = bytes32(
            inputs[MAIN_ZASSET_UTXO_OUT_COMMITMENT_2_IND]
        );
        bytes32 kytDepositSignedMessageHash = bytes32(
            inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND]
        );
        bytes32 kytWithdrawSignedMessageHash = bytes32(
            inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]
        );

        require(
            zAccountUtxoOutCommitment != 0 &&
                zAssetUtxoOutCommitment1 != 0 &&
                zAssetUtxoOutCommitment2 != 0 &&
                kytDepositSignedMessageHash != 0 &&
                kytWithdrawSignedMessageHash != 0,
            ERR_ZERO_COMITMENT
        );

        bytes32[] memory utxos = new bytes32[](5);
        utxos[0] = zAccountUtxoOutCommitment;
        utxos[1] = zAssetUtxoOutCommitment1;
        utxos[2] = zAssetUtxoOutCommitment2;
        utxos[3] = kytDepositSignedMessageHash;
        utxos[4] = kytWithdrawSignedMessageHash;

        if (transactionOptions.isTaxiApplicable()) {
            // first 3 utxos in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 3;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                utxos,
                miningRewards,
                numTaxiUtxos
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(utxos, miningRewards);
        }
    }

    function _insertZSwapUtxos(
        uint256[] calldata inputs,
        bytes32[2] memory zAssetUtxos,
        uint32 transactionOptions,
        uint96 miningRewards
    )
        internal
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        bytes32 zAccountUtxoOutCommitment = bytes32(
            inputs[ZSWAP_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
        );
        require(
            zAccountUtxoOutCommitment != 0 &&
                zAssetUtxos[0] != 0 &&
                zAssetUtxos[1] != 0,
            ERR_ZERO_COMITMENT
        );

        bytes32[] memory utxos = new bytes32[](3);
        utxos[0] = zAccountUtxoOutCommitment;
        utxos[1] = zAssetUtxos[0];
        utxos[2] = zAssetUtxos[1];

        if (transactionOptions.isTaxiApplicable()) {
            // All 3 utxos in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 3;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                utxos,
                miningRewards,
                numTaxiUtxos
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(utxos, miningRewards);
        }
    }

    function _addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 rewards
    )
        private
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        try
            IUtxoInserter(PANTHER_TREES).addUtxosToBusQueue(utxos, rewards)
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue) {
            zAccountUtxoQueueId = firstUtxoQueueId;
            zAccountUtxoIndexInQueue = firstUtxoIndexInQueue;
        } catch Error(string memory reason) {
            revert(reason);
        }

        zAccountUtxoBusQueuePos = _getZAccountUtxoBusQueuePos(
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue
        );
    }

    function _addUtxosToBusQueueAndTaxiTree(
        bytes32[] memory utxos,
        uint96 reward,
        uint8 numTaxiUtxos
    )
        private
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        try
            IUtxoInserter(PANTHER_TREES).addUtxosToBusQueueAndTaxiTree(
                utxos,
                reward,
                numTaxiUtxos
            )
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue) {
            zAccountUtxoQueueId = firstUtxoQueueId;
            zAccountUtxoIndexInQueue = firstUtxoIndexInQueue;
        } catch Error(string memory reason) {
            revert(reason);
        }

        zAccountUtxoBusQueuePos = _getZAccountUtxoBusQueuePos(
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue
        );
    }

    function _getZAccountUtxoBusQueuePos(
        uint256 zAccountUtxoQueueId,
        uint256 zAccountUtxoIndexInQueue
    ) private pure returns (uint256 zAccountUtxoBusQueuePos) {
        zAccountUtxoBusQueuePos =
            (zAccountUtxoQueueId << 8) |
            zAccountUtxoIndexInQueue;
    }
}
