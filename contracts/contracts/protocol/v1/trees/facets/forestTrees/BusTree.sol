// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./busTree//BusQueues.sol";
import "./busTree/MiningRewards.sol";
import "../../../verifier/Verifier.sol";

import "../../errMsgs/BusTreeErrMsgs.sol";
import "../../errMsgs/PantherBusTreeErrMsgs.sol";
import { TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT } from "../../utils/zeroTrees/Constants.sol";

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
 * Each time the Bus Tree root is updated, this contract MUST call PantherPoolV1
 * contract to trigger updates of that contract state (see PantherForest).
 */
abstract contract BusTree is BusQueues, MiningRewards, Verifier {
    bytes32 internal constant EMPTY_BUS_TREE_ROOT =
        TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT;

    // Number of levels in every Batch (that is a binary tree)
    uint256 internal constant BATCH_LEVELS = QUEUE_MAX_LEVELS;
    // Number of levels in every Branch, counting from roots of Batches
    uint256 private constant BRANCH_LEVELS = 10;
    // Number of Batches in a fully filled Branch
    uint256 private constant BRANCH_SIZE = 2 ** BRANCH_LEVELS;
    // Bitmask for cheaper modulo math
    uint256 private constant BRANCH_BITMASK = BRANCH_SIZE - 1;

    // timestamp to start adding utxo
    uint32 public busTreeStartTime;

    // keeps track of number of the added utxos
    uint32 public utxoCounter;

    // Number of Batches in the Bus Tree
    uint32 internal _numBatchesInBusTree;
    // Number of UTXOs (excluding empty leafs) in the tree
    uint32 internal _numUtxosInBusTree;
    // Block when the 1st Batch inserted in the latest branch
    uint40 internal _latestBranchFirstBatchBlock;
    // Block when the latest Batch inserted in the Bus Tree
    uint40 internal _latestBatchBlock;

    bytes32 internal _busTreeRoot;

    // address of circuitId
    uint160 public onboardingQueueCircuitId;

    event BusTreeInitialized(uint32 startBlockTime);
    event CircuitIdUpdated(uint160 circuitId);
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

    constructor(
        address feeMaster,
        address rewardToken,
        uint8 miningRewardVersion
    ) MiningRewards(feeMaster, rewardToken, miningRewardVersion) {}

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

    // Code of `function getBusTreeRoot` let avoid explicit initialization:
    // `busTreeRoot = EMPTY_BUS_TREE_ROOT`.
    // Initial value of storage variables is 0 (which is implicitly set in
    // new storage slots). There is no need for explicit initialization.
    function getBusTreeRoot() public view returns (bytes32) {
        return _busTreeRoot == bytes32(0) ? EMPTY_BUS_TREE_ROOT : _busTreeRoot;
    }

    function _onboardQueueAndAccountReward(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    ) internal returns (bytes32 busTreeNewRoot) {
        uint96 reward;
        (busTreeNewRoot, reward) = _onboardQueue(miner, queueId, inputs, proof);

        _busTreeRoot = busTreeNewRoot;

        _accountMinerRewards(queueId, miner, reward);
    }

    function _initializeBusTree(
        uint160 _onboardingQueueCircuitId,
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) internal {
        busTreeStartTime = uint32(block.timestamp);
        _updateCircuitId(_onboardingQueueCircuitId);

        _updateBusQueueRewardParams(
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );

        emit BusTreeInitialized(busTreeStartTime);
    }

    function _updateCircuitId(uint160 _circuitId) internal {
        onboardingQueueCircuitId = _circuitId;
        emit CircuitIdUpdated(_circuitId);
    }

    /// @dev ZK-circuit public signals:
    /// @param inputs[0] - oldRoot (BusTree root before insertion)
    /// @param inputs[1] - newRoot (BusTree root after insertion)
    /// @param inputs[2] - replacedNodeIndex
    /// @param inputs[3] - newLeafsCommitment (commitment to leafs in batch)
    /// @param inputs[4] - nNonEmptyNewLeafs (non-empty leafs in batch number)
    /// @param inputs[5] - batchRoot (Root of the batch to insert)
    /// @param inputs[6] - branchRoot (BusTree branch root after insertion)
    /// @param inputs[7] - extraInput (Hash of `miner` and `queueId`)
    /// @param inputs[8] - magicalConstraint (non-zero random number)
    function _onboardQueue(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    )
        private
        nonEmptyBusQueue(queueId)
        returns (bytes32 busTreeNewRoot, uint96 reward)
    {
        require(onboardingQueueCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        {
            bytes32 oldRoot = bytes32(inputs[0]);
            require(oldRoot == getBusTreeRoot(), ERR_INVALID_BUS_TREE_ROOT);
        }
        {
            bytes memory extraInput = abi.encodePacked(miner, queueId);
            uint256 extraInputHash = inputs[7];
            require(
                extraInputHash == uint256(keccak256(extraInput)) % FIELD_SIZE,
                ERR_INVALID_EXTRA_INP
            );
        }
        {
            uint256 magicalConstraint = inputs[8];
            require(magicalConstraint != 0, ERR_ZERO_MAGIC_CONSTR);
        }
        uint32 nBatches = _numBatchesInBusTree;
        {
            uint256 replacedNodeIndex = inputs[2];
            require(replacedNodeIndex == nBatches, ERR_INVALID_REPLACE_INDEX);
        }
        bytes32 commitment;
        uint8 nUtxos;
        (commitment, nUtxos, reward) = _setBusQueueAsProcessed(queueId);
        {
            uint256 newLeafsCommitment = inputs[3];
            require(
                newLeafsCommitment == uint256(commitment),
                ERR_INVALID_LEAFS_COMMIT
            );
        }
        {
            uint256 nNonEmptyNewLeafs = inputs[4];
            require(nNonEmptyNewLeafs == nUtxos, ERR_INVALID_LEAFS_NUM);
        }

        verifyOrRevert(onboardingQueueCircuitId, inputs, proof);

        bytes32 busBranchNewRoot = bytes32(inputs[6]);
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
        busTreeNewRoot = bytes32(inputs[1]);
        // Overflow impossible as nUtxos and _numBatchesInBusTree are limited
        _numBatchesInBusTree = nBatches + 1;
        _numUtxosInBusTree += nUtxos;
        // `<< BATCH_LEVELS` is equivalent to `* 2**BATCH_LEVELS`
        uint32 leftLeafIndex = nBatches << uint32(BATCH_LEVELS);
        bytes32 batchRoot = bytes32(inputs[5]);
        emit BusBatchOnboarded(
            queueId,
            batchRoot,
            nUtxos,
            leftLeafIndex,
            busTreeNewRoot,
            busBranchNewRoot
        );
    }
}
