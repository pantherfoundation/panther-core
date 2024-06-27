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

import "../../../common/crypto/PoseidonHashers.sol";

abstract contract UtxosInserter {
    using TransactionOptions for uint32;

    address public immutable PANTHER_BUS_TREE;
    address public immutable PANTHER_TAXI_TREE;

    constructor(address pantherBusTree, address pantherTaxiTree) {
        require(
            pantherBusTree != address(0) && pantherTaxiTree != address(0),
            "init:zero address"
        );
        PANTHER_BUS_TREE = pantherBusTree;
        PANTHER_TAXI_TREE = pantherTaxiTree;
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
        bytes32[] memory utxos = new bytes32[](2);
        utxos[0] = bytes32(inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_COMMITMENT_IND]);
        utxos[1] = bytes32(
            inputs[ZACCOUNT_ACTIVATION_KYC_SIGNED_MESSAGE_HASH_IND]
        );

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

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxoToBusQueue(zAccountUtxoOutCommitment, miningRewards);

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
        bytes32[] memory utxos = new bytes32[](2);
        utxos[0] = bytes32(
            inputs[PRP_CONVERSION_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
        );
        utxos[1] = zAssetUtxoOutCommitment;

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            // TODO: add 2 utxos to taxi
            _addThreeUtxosToTaxiTree(utxos[0], utxos[1], bytes32(0));
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
        bytes32[] memory utxos = new bytes32[](5);

        utxos[0] = bytes32(inputs[MAIN_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]);
        utxos[1] = bytes32(inputs[MAIN_ZASSET_UTXO_OUT_COMMITMENT_1_IND]);
        utxos[2] = bytes32(inputs[MAIN_ZASSET_UTXO_OUT_COMMITMENT_2_IND]);
        utxos[3] = bytes32(inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND]);
        utxos[4] = bytes32(inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]);

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addThreeUtxosToTaxiTree(utxos[0], utxos[1], utxos[2]);
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
        bytes32[] memory utxos = new bytes32[](5);

        utxos[0] = bytes32(inputs[ZSWAP_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]);
        utxos[1] = zAssetUtxos[0];
        utxos[2] = zAssetUtxos[1];
        utxos[3] = bytes32(inputs[ZSWAP_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND]);
        utxos[4] = bytes32(inputs[ZSWAP_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]);

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addThreeUtxosToTaxiTree(utxos[0], utxos[1], utxos[2]);
        }
    }

    function _tempInsertZSwapUtxos(
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
        bytes32[] memory utxos = new bytes32[](5);

        utxos[0] = bytes32(inputs[41]); // zAccount index
        utxos[1] = zAssetUtxos[0];
        utxos[2] = zAssetUtxos[1];
        utxos[3] = bytes32(inputs[ZSWAP_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND]);
        utxos[4] = bytes32(inputs[ZSWAP_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]);

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _addUtxosToBusQueue(utxos, miningRewards);

        if (transactionOptions.isTaxiApplicable()) {
            _addThreeUtxosToTaxiTree(utxos[0], utxos[1], utxos[2]);
        }
    }

    function _addUtxoToBusQueue(
        bytes32 utxo,
        uint96 /*rewards*/
    )
        private
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        // TODO: Add reward
        try IBusTree(PANTHER_BUS_TREE).addUtxoToBusQueue(utxo) returns (
            uint32 queueId,
            uint8 indexInQueue
        ) {
            zAccountUtxoQueueId = queueId;
            zAccountUtxoIndexInQueue = indexInQueue;
        } catch Error(string memory reason) {
            revert(reason);
        }

        zAccountUtxoBusQueuePos =
            (uint256(zAccountUtxoQueueId) << 8) |
            uint256(zAccountUtxoIndexInQueue);
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
            IBusTree(PANTHER_BUS_TREE).addUtxosToBusQueue(utxos, rewards)
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue) {
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
            IPantherTaxiTree(PANTHER_TAXI_TREE).addUtxo(utxo)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _addThreeUtxosToTaxiTree(
        bytes32 utxo0,
        bytes32 utxo1,
        bytes32 utxo2
    ) private {
        try
            IPantherTaxiTree(PANTHER_TAXI_TREE).addThreeUtxos(
                utxo0,
                utxo1,
                utxo2
            )
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}
