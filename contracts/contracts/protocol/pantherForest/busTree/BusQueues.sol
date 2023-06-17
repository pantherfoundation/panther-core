// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../merkleTrees/DegenerateIncrementalBinaryTree.sol";

/**
 * @dev It handles "queues" of commitments to UTXOs (further - "UTXOs").
 * Queue is an (ordered) list of UTXOs. All UTXOs in a queue are supposed to be
 * processed at once (i.e. as a batch of UTXOs). But queues may be processed in
 * any order (so, say, the 3rd queue may be processed before the 1st one).
 * To save gas, this contract
 * - stores the commitment to UTXOs in a queue (but not UTXOs) in the storage
 * - computes the commitment as the root of a degenerate tree (not binary one)
 * built from UTXOs (think of it as a "chain" of UTXOs).
 * For every queue, it also records the amount of rewards associated with the
 * Queue (think of "reward for processing the queue").
 * Queue has the following lifecycle:
 * opened -> extended -> (optionally) filled -> (onboarded and) deleted.
 */
abstract contract BusQueues is DegenerateIncrementalBinaryTree {
    // solhint-disable-next-line var-name-mixedcase
    uint256 private constant QUEUE_SIZE = 64;

    struct BusQueue {
        uint8 nUtxos;
        uint96 reward;
    }

    // Mapping from queue ID to queue params
    mapping(uint32 => BusQueue) internal busQueueParams;
    // Mapping from queue ID to queue commitment
    mapping(uint32 => bytes32) internal busQueueCommitments;

    // ID of the currently "open" queue
    uint32 private curBusQueueId;
    // Number of filled non-deleted queues
    uint32 private numFilledQueues;

    // Emitted for every UTXO appended to a queue
    event UtxoBusQueued(
        bytes32 indexed utxo,
        uint256 indexed queueId,
        uint256 utxoIndexInBatch
    );

    // Emitted when a new queue is opened (it becomes the "current" one)
    event BusQueueOpened(uint256 queueId);

    // Emitted when new UTXOs appended to a queue
    event BusQueueExtended(
        uint256 indexed queueId,
        uint256 totalNumUtxos,
        uint256 accumReward
    );

    // Emitted when a queue gets its maximum size (and it is "closed")
    event BusQueueFilled(uint256 indexed queueId);

    // Emitted when a queue is deleted (disposed)
    event BusQueueDeleted(uint256 indexed queueId);

    // Emitted when queue reward increased w/o appending UTXOs
    event BusQueueRewardAdded(uint256 indexed queueId, uint256 accumReward);

    modifier nonEmptyBusQueue(uint32 queueId) {
        require(busQueueParams[queueId].nUtxos > 0, "BQ:EMPTY_QUEUE");
        _;
    }

    constructor() {
        // Initial value of storage variables is 0 (which is implicitly set in
        // new storage slots). No explicit initialization needed.
        emit BusQueueOpened(0);
    }

    function getQueue(uint32 queueId)
        public
        view
        returns (
            bytes32 commitment,
            uint8 nUtxos,
            uint96 reward
        )
    {
        commitment = busQueueCommitments[queueId];
        nUtxos = busQueueParams[queueId].nUtxos;
        reward = busQueueParams[queueId].reward;
    }

    // @dev Code that calls it MUST ensure utxos[i] < FIELD_SIZE
    function addUtxosToBusQueue(bytes32[] memory utxos, uint96 reward)
        internal
    {
        uint32 queueId = curBusQueueId;
        BusQueue memory queue = busQueueParams[queueId];
        bytes32 commitment = busQueueCommitments[queueId];

        for (uint256 n = 0; n < utxos.length; n++) {
            bytes32 utxo = utxos[n];
            commitment = insertLeaf(utxo, commitment, queue.nUtxos == 0);
            emit UtxoBusQueued(utxo, queueId, queue.nUtxos);
            queue.nUtxos += 1;

            // If the current queue gets fully populated, switch to a new queue
            if (queue.nUtxos == QUEUE_SIZE) {
                // Part of the reward relates to the populated queue
                uint96 rewardUsed = uint96(
                    (uint256(reward) * (n + 1)) / utxos.length
                );
                queue.reward += rewardUsed;
                // Remaining reward is for the new queue
                reward -= rewardUsed;

                // Close the current queue
                busQueueParams[queueId] = queue;
                busQueueCommitments[queueId] = commitment;
                emit BusQueueExtended(queueId, queue.nUtxos, queue.reward);
                emit BusQueueFilled(queueId);

                // Open a new queue
                (queueId, queue) = openNewBusQueue();
                numFilledQueues += 1;
                commitment = 0;
            }
        }

        if (queue.nUtxos > 0) {
            queue.reward += reward;
            busQueueParams[queueId] = queue;
            busQueueCommitments[queueId] = commitment;
            emit BusQueueExtended(queueId, queue.nUtxos, queue.reward);
        }
    }

    function deleteBusQueue(uint32 queueId) internal nonEmptyBusQueue(queueId) {
        busQueueParams[queueId] = BusQueue(0, 0);
        busQueueCommitments[queueId] = bytes32(0);
        numFilledQueues -= 1;
        emit BusQueueDeleted(queueId);
    }

    function registerExtraReward(uint32 queueId, uint96 extraReward)
        internal
        nonEmptyBusQueue(queueId)
    {
        require(extraReward > 0, "BQ:ZERO_REWARD");
        uint96 accumReward;
        unchecked {
            // Values are supposed to be too small to cause overflow
            accumReward = busQueueParams[queueId].reward + extraReward;
            busQueueParams[queueId].reward = accumReward;
        }
        emit BusQueueRewardAdded(queueId, accumReward);
    }

    function openNewBusQueue()
        private
        returns (uint32 newQueueId, BusQueue memory queue)
    {
        unchecked {
            // (Theoretical) overflow is acceptable
            newQueueId = curBusQueueId + 1;
        }
        curBusQueueId = newQueueId;
        queue = BusQueue(0, 0);
        // New storage slots contains zeros, so
        // no extra initialization for `busQueueParams[newQueueId]` needed

        emit BusQueueOpened(newQueueId);
    }
}
