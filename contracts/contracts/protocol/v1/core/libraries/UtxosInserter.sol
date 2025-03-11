// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IUtxoInserter.sol";

import "./TransactionOptions.sol";
import "../publicSignals/ZAccountActivationPublicSignals.sol";
import "../publicSignals/ZAccountRenewalPublicSignals.sol";
import "../publicSignals/PrpAccountingPublicSignals.sol";
import "../publicSignals/PrpConversionPublicSignals.sol";
import "../publicSignals/MainPublicSignals.sol";
import "../publicSignals/ZSwapPublicSignals.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

string constant ERR_ZERO_COMITMENT = "UI:E1";

library UtxosInserter {
    using TransactionOptions for uint32;

    /**
     * @notice Inserts UTXOs related to ZAccount renewal.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param inputs Array containing necessary inputs for ZAccount activation.
     * @param transactionOptions Options for the transaction.
     * @param miningRewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts two UTXOs for ZAccount activation. Requires a non-zero zAccount
     * commitment and KYC signed message hash.
     */
    function insertZAccountRenewalUtxos(
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
                inputs[ZACCOUNT_RENEWAL_UTXO_OUT_COMMITMENT_IND]
            );
            bytes32 kycSignedMessageHash = bytes32(
                inputs[ZACCOUNT_RENEWAL_KYC_SIGNED_MESSAGE_HASH_IND]
            );
            require(
                zAccountUtxoOutCommitment != 0 && kycSignedMessageHash != 0,
                ERR_ZERO_COMITMENT
            );

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = kycSignedMessageHash;
        }

        bytes32 forestRoot = bytes32(
            inputs[ZACCOUNT_RENEWAL_FOREST_MERKLE_ROOT_IND]
        );
        bytes32 staticRoot = bytes32(
            inputs[ZACCOUNT_RENEWAL_STATIC_MERKLE_ROOT_IND]
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

    /**
     * @notice Inserts UTXOs related to ZAccount activation.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param inputs Array containing necessary inputs for ZAccount activation.
     * @param transactionOptions Options for the transaction.
     * @param miningRewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts two UTXOs for ZAccount activation. Requires a non-zero zAccount
     * commitment and KYC signed message hash.
     */
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

    /**
     * @notice Inserts UTXO for PRP claim.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param inputs Array containing necessary inputs for PRP claim.
     * @param transactionOptions Options for the transaction.
     * @param miningRewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts one UTXO for PRP claim. Requires a non-zero commitment. Requires
     * non-zero zAccount commitment.
     */
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

    /**
     * @notice Inserts UTXOs for PRP conversion.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param inputs Array containing necessary inputs for PRP conversion.
     * @param zAssetUtxoOutCommitment The commitment for the zAsset UTXO.
     * @param transactionOptions Options for the transaction.
     * @param miningRewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts two UTXOs for PRP conversion. Requires non-zero zAccount and
     * zAsset commitments.
     */
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

    /**
     * @notice Inserts UTXOs for the main protocol process.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param inputs Array containing necessary inputs for the main protocol.
     * @param transactionOptions Options for the transaction.
     * @param miningRewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts five UTXOs for the main protocol. Requires non-zero ZAccount and
     * zAssets commitments, and, KYT message hashes.
     */
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
        bytes32[] memory utxos = new bytes32[](4);

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
            bytes32 kytInternalSignedMessageHash = bytes32(
                inputs[MAIN_KYT_INTERNAL_SIGNED_MESSAGE_HASH_IND]
            );

            require(
                zAccountUtxoOutCommitment != 0 &&
                    zAssetUtxoOutCommitment1 != 0 &&
                    zAssetUtxoOutCommitment2 != 0 &&
                    kytDepositSignedMessageHash != 0 &&
                    kytWithdrawSignedMessageHash != 0 &&
                    kytInternalSignedMessageHash != 0,
                ERR_ZERO_COMITMENT
            );

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = zAssetUtxoOutCommitment1;
            utxos[2] = zAssetUtxoOutCommitment2;
            utxos[3] = PoseidonHashers.poseidonT4(
                [
                    kytDepositSignedMessageHash,
                    kytWithdrawSignedMessageHash,
                    kytInternalSignedMessageHash
                ]
            );
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

    /**
     * @notice Inserts UTXOs for a ZSwap operation.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param inputs Array containing necessary inputs for ZSwap.
     * @param zAssetUtxos Array of UTXO commitments for the zAssets involved in the swap.
     * @param transactionOptions Options for the transaction.
     * @param miningRewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts three UTXOs for the ZSwap operation. Requires non-zero commitments
     * for zAccount and zAssets.
     */
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

    /**
     * @notice Adds UTXOs to the bus queue.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param utxos Array of UTXOs to be inserted.
     * @param cachedForestRootIndex The index of the cached forest Merkle root.
     * @param forestRoot The Merkle root of the forest.
     * @param staticRoot The static Merkle root.
     * @param rewards The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts UTXOs into the bus queue and calculates their queue position.
     */
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

    /**
     * @notice Adds UTXOs to both the bus queue and taxi tree.
     * @param pantherTrees The address of the Panther Trees Diamond proxy.
     * @param utxos Array of UTXOs to be inserted.
     * @param numTaxiUtxos The number of UTXOs to be added to the taxi tree.
     * @param cachedForestRootIndex The index of the cached forest Merkle root.
     * @param forestRoot The Merkle root of the forest.
     * @param staticRoot The static Merkle root.
     * @param reward The mining rewards to include in the UTXO insertion.
     * @return zAccountUtxoQueueId The queue ID of the inserted UTXO.
     * @return zAccountUtxoIndexInQueue The index of the inserted UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The bus queue position of the inserted UTXO.
     * @dev Inserts UTXOs into both the bus queue and taxi tree. Calculates the UTXO
     * bus queue position.
     */
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

    /**
     * @notice Calculates the position of a UTXO in the bus queue.
     * @param zAccountUtxoQueueId The queue ID of the UTXO.
     * @param zAccountUtxoIndexInQueue The index of the UTXO in the queue.
     * @return zAccountUtxoBusQueuePos The calculated bus queue position of the UTXO.
     * @dev Combines the queue ID and index to determine the UTXO's position in the bus queue.
     */
    function _getZAccountUtxoBusQueuePos(
        uint256 zAccountUtxoQueueId,
        uint256 zAccountUtxoIndexInQueue
    ) private pure returns (uint256 zAccountUtxoBusQueuePos) {
        zAccountUtxoBusQueuePos =
            (zAccountUtxoQueueId << 8) |
            zAccountUtxoIndexInQueue;
    }
}
