// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./BusQueues.sol";
import "../../interfaces/IPantherVerifier.sol";
import { EMPTY_BUS_TREE_ROOT } from "../zeroTrees/Constants.sol";
import { MAGICAL_CONSTRAINT } from "../../crypto/SnarkConstants.sol";

/**
 * @dev The Bus Tree ("Tree") is an incremental binary Merkle tree that stores
 * commitments to UTXOs (further referred to as "UTXOs").
 * Unfilled part of the Tree contains leafs with a special "zero" value - such
 * leafs are deemed to be "empty".
 * UTXOs are inserted in the Tree in batches called "Queues".
 * The contract does not compute the Tree's root on-chain. Instead, it verifies
 * the SNARK-proof, which proves correctness of insertion into the Tree.
 * For efficient proving, leafs of a Queue get re-organized into a binary fully
 * balanced Merkle tree called the "Batch". If there are less UTXOs in a Queue
 * than needed to fill the Batch, empty leafs are appended. This way, insertion
 * constitutes replacement of an inner node of the Tree with the Batch root.
 * To ease off-chain re-construction, roots of Tree's branches ("Branches") are
 * published via on-chain logs.
 */
abstract contract BusTree is BusQueues {
    // solhint-disable var-name-mixedcase

    // Number of levels in every Batch (that is a binary tree)
    uint256 internal constant BATCH_LEVELS = QUEUE_MAX_LEVELS;

    // Number of levels in every Branch, counting from roots of Batches
    uint256 private constant BRANCH_LEVELS = 10;
    // Number of Batches in a fully filled Branch
    uint256 private constant BRANCH_SIZE = 2**BRANCH_LEVELS;
    // Bitmask for cheaper modulo math
    uint256 private constant BRANCH_BITMASK = BRANCH_SIZE - 1;

    IPantherVerifier public immutable VERIFIER;
    uint160 public immutable CIRCUIT_ID;
    // solhint-enable var-name-mixedcase

    bytes32 public busTreeRoot;

    // Number of Batches in the Bus Tree
    uint32 private _numBatchesInBusTree;
    // Number of UTXOs (excluding empty leafs) in the tree
    uint32 private _numUtxosInBusTree;
    // Block when the 1st Batch inserted in the latest branch
    uint40 private _latestBranchFirstBatchBlock;
    // Block when the latest Batch inserted in the Bus Tree
    uint40 private _latestBatchBlock;

    event BusBatchOnboarded(
        uint256 indexed queueId,
        bytes32 indexed batchRoot,
        uint256 numUtxosInBatch,
        // The index of a UTXO's leaf in the Bus Tree is
        // `leftLeafIndexInBusTree + UtxoBusQueued::utxoIndexInBatch`
        uint256 leftLeafIndexInBusTree,
        bytes32 busTreeNewRoot,
        bytes32 busBranchNewRoot
    );

    event BusBranchFilled(
        uint256 indexed branchIndex,
        bytes32 busBranchFinalRoot
    );

    // @dev It is "proxy-friendly" as it does not change the storage
    constructor(address _verifier, uint160 _circuitId) {
        require(
            IPantherVerifier(_verifier).getVerifyingKey(_circuitId).ic.length >=
                1,
            "BT:INVALID_VK"
        );
        VERIFIER = IPantherVerifier(_verifier);
        CIRCUIT_ID = _circuitId;
        // Code of `function onboardQueue` let avoid explicit initialization:
        // `busTreeRoot = EMPTY_BUS_TREE_ROOT`.
        // Initial value of storage variables is 0 (which is implicitly set in
        // new storage slots). There is no need for explicit initialization.
    }

    function getBusTreeStats()
        external
        view
        returns (
            uint32 numBatchesInBusTree,
            uint32 numUtxosInBusTree,
            uint40 latestBranchFirstBatchBlock,
            uint40 latestBatchBlock
        )
    {
        numBatchesInBusTree = _numBatchesInBusTree;
        numUtxosInBusTree = _numUtxosInBusTree;
        latestBranchFirstBatchBlock = _latestBranchFirstBatchBlock;
        latestBatchBlock = _latestBatchBlock;
    }

    function onboardQueue(
        address miner,
        uint32 queueId,
        bytes32 busTreeNewRoot,
        bytes32 batchRoot,
        bytes32 busBranchNewRoot,
        SnarkProof memory proof
    ) external nonEmptyBusQueue(queueId) {
        uint32 nBatches = _numBatchesInBusTree;
        (
            bytes32 commitment,
            uint8 nUtxos,
            uint96 reward
        ) = setBusQueueAsProcessed(queueId);

        // Circuit public input signals
        uint256[] memory input = new uint256[](9);
        // `oldRoot` signal
        input[0] = nBatches == 0
            ? uint256(EMPTY_BUS_TREE_ROOT)
            : uint256(busTreeRoot);
        // `newRoot` signal
        input[1] = uint256(busTreeNewRoot);
        // `replacedNodeIndex` signal
        input[2] = nBatches;
        // `newLeafsCommitment` signal
        input[3] = uint256(commitment);
        // `nNonEmptyNewLeafs` signal
        input[4] = uint256(nUtxos);
        // `batchRoot` signal
        input[5] = uint256(batchRoot);
        // `branchRoot` signal
        input[6] = uint256(busBranchNewRoot);
        // `extraInput` signal (front-run protection)
        input[7] = uint256(uint160(miner));
        // magicalConstraint
        input[8] = MAGICAL_CONSTRAINT;

        // Verify the proof
        require(VERIFIER.verify(CIRCUIT_ID, input, proof), "BT:FAILED_PROOF");

        {
            // Overflow risk ignored
            uint40 curBlock = uint40(block.number);
            _latestBatchBlock = curBlock;

            // `& BRANCH_BITMASK` is equivalent to `% BRANCH_SIZE`
            uint256 batchBranchIndex = uint256(nBatches) & BRANCH_BITMASK;
            if (batchBranchIndex == 0) {
                _latestBranchFirstBatchBlock = curBlock;
            } else {
                if (batchBranchIndex + 1 == BRANCH_SIZE) {
                    // `>>BRANCH_LEVELS` is equivalent to `/BRANCH_SIZE`
                    uint256 branchIndex = nBatches >> BRANCH_LEVELS;
                    emit BusBranchFilled(branchIndex, busBranchNewRoot);
                }
            }
        }

        // Store updated Bus Tree params
        busTreeRoot = busTreeNewRoot;
        // Overflow impossible as nUtxos and _numBatchesInBusTree are limited
        _numBatchesInBusTree = nBatches + 1;
        _numUtxosInBusTree += nUtxos;

        // `<< BATCH_LEVELS` is equivalent to `* 2**BATCH_LEVELS`
        uint32 leftLeafIndex = nBatches << BATCH_LEVELS;

        emit BusBatchOnboarded(
            queueId,
            batchRoot,
            nUtxos,
            leftLeafIndex,
            busTreeNewRoot,
            busBranchNewRoot
        );

        rewardMiner(miner, reward);
    }

    function rewardMiner(address miner, uint256 reward) internal virtual;
}
