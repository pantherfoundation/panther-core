// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../interfaces/IPantherTaxiTree.sol";
import "../interfaces/IBusTree.sol";

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

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addUtxoToTaxiTree(utxos[0]);
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

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addUtxoToTaxiTree(zAccountUtxoOutCommitment);
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

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addUtxosToTaxiTree(utxos);
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

        bytes32[] memory busUtxos = new bytes32[](5);
        busUtxos[0] = zAccountUtxoOutCommitment;
        busUtxos[1] = zAssetUtxoOutCommitment1;
        busUtxos[2] = zAssetUtxoOutCommitment2;
        busUtxos[3] = kytDepositSignedMessageHash;
        busUtxos[4] = kytWithdrawSignedMessageHash;

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(busUtxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            bytes32[] memory taxiUtxos = new bytes32[](3);
            taxiUtxos[0] = zAccountUtxoOutCommitment;
            taxiUtxos[1] = zAssetUtxoOutCommitment1;
            taxiUtxos[2] = zAssetUtxoOutCommitment2;

            _addUtxosToTaxiTree(taxiUtxos);
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

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addUtxosToTaxiTree(utxos);
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
        try IBusTree(PANTHER_TREES).addUtxosToBusQueue(utxos, rewards) returns (
            uint32 firstUtxoQueueId,
            uint8 firstUtxoIndexInQueue
        ) {
            zAccountUtxoQueueId = firstUtxoQueueId;
            zAccountUtxoIndexInQueue = firstUtxoIndexInQueue;
        } catch Error(string memory reason) {
            revert(reason);
        }

        zAccountUtxoBusQueuePos =
            (uint256(zAccountUtxoQueueId) << 8) |
            uint256(zAccountUtxoIndexInQueue);
    }

    function _addUtxoToTaxiTree(bytes32 utxo) private {
        try
            IPantherTaxiTree(PANTHER_TREES).addUtxoToTaxiTree(utxo)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _addUtxosToTaxiTree(bytes32[] memory utxos) private {
        try
            IPantherTaxiTree(PANTHER_TREES).addUtxos(utxos)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}
