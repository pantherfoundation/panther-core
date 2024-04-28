// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IPantherTaxiTree.sol";
import "../interfaces/IBusTree.sol";

import "./TransactionOptions.sol";
import "./publicSignals/ZAccountActivationPublicSignals.sol";
import "./publicSignals/PrpClaimPublicSignals.sol";
import "./publicSignals/PrpConversionPublicSignals.sol";
import "./publicSignals/MainPublicSignals.sol";

import "../../../common/crypto/PoseidonHashers.sol";

abstract contract UtxoCollector {
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
        utxos[0] = bytes32(inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_COMMITMENT]);
        utxos[1] = bytes32(inputs[ZACCOUNT_ACTIVATION_KYC_SIGNED_MESSAGE_HASH]);

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
            inputs[PRP_CLAIM_ZACCOUNT_UTXO_OUT_COMMITMENT]
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
        uint256 zkpAmountScaled,
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
        utxos[0] = bytes32(inputs[PRP_CONVERSION_ZACCOUNT_UTXO_OUT_COMMITMENT]);
        utxos[1] = _generateZAssetUtxoCommitment(
            zkpAmountScaled,
            inputs[PRP_CONVERSION_UTXO_COMMITMENT_PRIVATE_PART]
        );

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

        utxos[0] = bytes32(inputs[MAIN_ZACCOUNT_UTXO_OUT_COMMITMENT]);
        utxos[1] = bytes32(inputs[MAIN_ZASSET_UTXO_OUT_COMMITMENT_1]);
        utxos[2] = bytes32(inputs[MAIN_ZASSET_UTXO_OUT_COMMITMENT_2]);
        utxos[3] = bytes32(inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH]);
        utxos[4] = bytes32(inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH]);

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

    function _generateZAssetUtxoCommitment(
        uint256 zAssetScaledAmount,
        uint256 zAssetutxoCommitmentPrivatePart
    ) private pure returns (bytes32) {
        return
            PoseidonHashers.poseidonT3(
                [
                    bytes32(zAssetScaledAmount),
                    bytes32(zAssetutxoCommitmentPrivatePart)
                ]
            );
    }
}
