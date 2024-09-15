// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IUtxoInserter.sol";

import "./TransactionOptions.sol";
import "../publicSignals/ZAccountActivationPublicSignals.sol";
import "../publicSignals/PrpAccountingPublicSignals.sol";
import "../publicSignals/PrpConversionPublicSignals.sol";
import "../publicSignals/MainPublicSignals.sol";
import "../publicSignals/ZSwapPublicSignals.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

string constant ERR_ZERO_COMITMENT = "UI:E1";

library UtxosInserter {
    using TransactionOptions for uint32;

    function insertZAccountActivationUtxos(
        address pantherTrees,
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

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = kycSignedMessageHash;
        }

        bytes32 forestRoot = bytes32(
            inputs[ZACCOUNT_ACTIVATION_FOREST_MERKLE_ROOT_IND]
        );
        bytes32 staticRoot = bytes32(
            inputs[ZACCOUNT_ACTIVATION_STATIC_MERKLE_ROOT_IND]
        );

        if (transactionOptions.isTaxiApplicable()) {
            // first utxo in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 1;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                pantherTrees,
                utxos,
                numTaxiUtxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(
                pantherTrees,
                utxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        }
    }

    function insertPrpClaimUtxo(
        address pantherTrees,
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
        bytes32[] memory utxos = new bytes32[](1);

        {
            bytes32 zAccountUtxoOutCommitment = bytes32(
                inputs[PRP_ACCOUNTING_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
            );
            require(zAccountUtxoOutCommitment != 0, ERR_ZERO_COMITMENT);

            utxos[0] = zAccountUtxoOutCommitment;
        }

        bytes32 forestRoot = bytes32(
            inputs[PRP_ACCOUNTING_FOREST_MERKLE_ROOT_IND]
        );
        bytes32 staticRoot = bytes32(
            inputs[PRP_ACCOUNTING_STATIC_MERKLE_ROOT_IND]
        );

        if (transactionOptions.isTaxiApplicable()) {
            // first utxo in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 1;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                pantherTrees,
                utxos,
                numTaxiUtxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(
                pantherTrees,
                utxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        }
    }

    function insertPrpConversionUtxos(
        address pantherTrees,
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

        {
            bytes32 zAccountUtxoOutCommitment = bytes32(
                inputs[PRP_CONVERSION_ZACCOUNT_UTXO_OUT_COMMITMENT_IND]
            );
            require(
                zAccountUtxoOutCommitment != 0 && zAssetUtxoOutCommitment != 0,
                ERR_ZERO_COMITMENT
            );

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = zAssetUtxoOutCommitment;
        }

        bytes32 forestRoot = bytes32(
            inputs[PRP_CONVERSION_FOREST_MERKLE_ROOT_IND]
        );
        bytes32 staticRoot = bytes32(
            inputs[PRP_CONVERSION_STATIC_MERKLE_ROOT_IND]
        );

        if (transactionOptions.isTaxiApplicable()) {
            // All 2 utxos in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 2;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                pantherTrees,
                utxos,
                numTaxiUtxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(
                pantherTrees,
                utxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        }
    }

    function insertMainUtxos(
        address pantherTrees,
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

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = zAssetUtxoOutCommitment1;
            utxos[2] = zAssetUtxoOutCommitment2;
            utxos[3] = kytDepositSignedMessageHash;
            utxos[4] = kytWithdrawSignedMessageHash;
        }

        bytes32 forestRoot = bytes32(inputs[MAIN_FOREST_MERKLE_ROOT_IND]);
        bytes32 staticRoot = bytes32(inputs[MAIN_STATIC_MERKLE_ROOT_IND]);

        if (transactionOptions.isTaxiApplicable()) {
            // first 3 utxos in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 3;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                pantherTrees,
                utxos,
                numTaxiUtxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(
                pantherTrees,
                utxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        }
    }

    function insertZSwapUtxos(
        address pantherTrees,
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
        bytes32[] memory utxos = new bytes32[](3);

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

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = zAssetUtxos[0];
            utxos[2] = zAssetUtxos[1];
        }

        bytes32 forestRoot = bytes32(inputs[ZSWAP_FOREST_MERKLE_ROOT_IND]);
        bytes32 staticRoot = bytes32(inputs[ZSWAP_STATIC_MERKLE_ROOT_IND]);

        if (transactionOptions.isTaxiApplicable()) {
            // All 3 utxos in the utxos[] shall be added to taxi
            uint8 numTaxiUtxos = 3;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueueAndTaxiTree(
                pantherTrees,
                utxos,
                numTaxiUtxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        } else {
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(
                pantherTrees,
                utxos,
                transactionOptions.cachedForestRootIndex(),
                forestRoot,
                staticRoot,
                miningRewards
            );
        }
    }

    function _addUtxosToBusQueue(
        address pantherTrees,
        bytes32[] memory utxos,
        uint256 cachedForestRootIndex,
        bytes32 forestRoot,
        bytes32 staticRoot,
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
            IUtxoInserter(pantherTrees).addUtxosToBusQueue(
                utxos,
                cachedForestRootIndex,
                forestRoot,
                staticRoot,
                rewards
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

    function _addUtxosToBusQueueAndTaxiTree(
        address pantherTrees,
        bytes32[] memory utxos,
        uint8 numTaxiUtxos,
        uint256 cachedForestRootIndex,
        bytes32 forestRoot,
        bytes32 staticRoot,
        uint96 reward
    )
        private
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        try
            IUtxoInserter(pantherTrees).addUtxosToBusQueueAndTaxiTree(
                utxos,
                numTaxiUtxos,
                cachedForestRootIndex,
                forestRoot,
                staticRoot,
                reward
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
