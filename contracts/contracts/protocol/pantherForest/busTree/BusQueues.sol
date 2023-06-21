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
 * If a Queue is fully populated with UTXOs but not yet processed, the Queue is
 * considered to be "pending" processing. As a main scenario, pending Queues are
 * expected to be processed. However, partially filled Queues may be processed
 * also. So, a Queue has the following lifecycle:
 * Opened -> (optionally) Pending processing -> Processed (and deleted).
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

    // ID of the "opened" queue (next UTXO will be appended to this queue)
    uint32 private _curQueueId;
    // Number of filled non-deleted queues
    uint32 private _numPendingQueues;
    // Total rewards associated with filled non-deleted queues
    uint96 private _numPendingRewards;

    // Emitted for every UTXO appended to a queue
    event UtxoBusQueued(
        bytes32 indexed utxo,
        uint256 indexed queueId,
        uint256 utxoIndexInBatch
    );

    // Emitted when a new queue is opened (it becomes the "current" one)
    event BusQueueOpened(uint256 queueId);

    // Emitted when a queue gets its maximum size (no more UTXOs can be added,
    // the queue pends processing), or queue reward increased w/o adding UTXOs
    event BusQueuePending(uint256 indexed queueId, uint256 accumReward);

    // Emitted when a queue is registered as the processed one (and deleted)
    event BusQueueProcessed(uint256 indexed queueId);

    modifier nonEmptyBusQueue(uint32 queueId) {
        require(busQueueParams[queueId].nUtxos > 0, "BQ:EMPTY_QUEUE");
        _;
    }

    constructor() {
        // Initial value of storage variables is 0 (which is implicitly set in
        // new storage slots). There is no need for explicit initialization.
        emit BusQueueOpened(0);
    }

    function getBusQueuesStats()
        external
        view
        returns (
            uint32 curQueueId,
            uint8 curQueueNumUtxos,
            uint96 curQueueReward,
            uint32 numPendingQueues,
            uint96 numPendingRewards
        )
    {
        curQueueId = _curQueueId;
        curQueueNumUtxos = busQueueParams[curQueueId].nUtxos;
        curQueueReward = busQueueParams[curQueueId].reward;
        numPendingQueues = _numPendingQueues;
        numPendingRewards = _numPendingRewards;
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
        uint32 cQueueId = _curQueueId;
        BusQueue memory queue = busQueueParams[cQueueId];
        bytes32 commitment = busQueueCommitments[cQueueId];

        for (uint256 n = 0; n < utxos.length; n++) {
            bytes32 utxo = utxos[n];
            commitment = insertLeaf(utxo, commitment, queue.nUtxos == 0);
            emit UtxoBusQueued(utxo, cQueueId, queue.nUtxos);
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
                busQueueParams[cQueueId] = queue;
                busQueueCommitments[cQueueId] = commitment;
                _numPendingQueues += 1;
                _numPendingRewards += queue.reward;
                emit BusQueuePending(cQueueId, queue.reward);

                // Open a new queue
                (cQueueId, queue) = openNewBusQueue();
                commitment = 0;
            }
        }

        if (queue.nUtxos > 0) {
            queue.reward += reward;
            busQueueParams[cQueueId] = queue;
            busQueueCommitments[cQueueId] = commitment;
        }
    }

    // It returns params of the deleted queue
    function setBusQueueAsProcessed(uint32 queueId)
        internal
        nonEmptyBusQueue(queueId)
        returns (
            bytes32 commitment,
            uint8 nUtxos,
            uint96 reward
        )
    {
        (commitment, nUtxos, reward) = getQueue(queueId);

        busQueueParams[queueId] = BusQueue(0, 0);
        busQueueCommitments[queueId] = bytes32(0);
        if (nUtxos == QUEUE_SIZE) {
            _numPendingQueues -= 1;
            _numPendingRewards -= reward;
        }

        emit BusQueueProcessed(queueId);

        if (queueId == _curQueueId) openNewBusQueue();
    }

    function addBusQueueReward(uint32 queueId, uint96 extraReward)
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
        emit BusQueuePending(queueId, accumReward);
    }

    function openNewBusQueue()
        private
        returns (uint32 newQueueId, BusQueue memory queue)
    {
        unchecked {
            // (Theoretical) overflow is acceptable
            newQueueId = _curQueueId + 1;
        }
        _curQueueId = newQueueId;
        queue = BusQueue(0, 0);
        // New storage slots contains zeros, so
        // no extra initialization for `busQueueParams[newQueueId]` needed

        emit BusQueueOpened(newQueueId);
    }
}
