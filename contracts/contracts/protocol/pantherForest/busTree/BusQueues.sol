// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { FIELD_SIZE } from "../../crypto/SnarkConstants.sol";
import "../merkleTrees/DegenerateIncrementalBinaryTree.sol";

abstract contract BusQueues is DegenerateIncrementalBinaryTree {
    uint256 internal constant QUEUE_SIZE_BIT = 6;
    uint256 internal constant QUEUE_SIZE = 2**QUEUE_SIZE_BIT;

    struct BusQueue {
        bytes32 commitment;
        uint8 nUtxos;
        uint96 reward;
    }

    // Queue lifecycle: opened -> extended -> closed (optionally) -> onboarded
    event BusQueueOpened(uint256 queueId);
    event BusQueueExtended(
        uint256 indexed queueId,
        uint256 nUtxos,
        uint256 reward
    );
    event BusQueueClosed(
        uint256 indexed queueId,
        uint256 nUtxos,
        uint256 reward
    );
    event BusQueueOnboarded(
        uint256 indexed queueId,
        uint256 nUtxos,
        uint256 firstIndex
    );
    event BusQueueRewardAdded(uint256 indexed queueId, uint256 accumReward);
    event UtxoBusQueued(
        bytes32 indexed utxo,
        uint256 indexed queueId,
        uint256 index
    );

    // Mapping from queue ID to queue params
    mapping(uint32 => BusQueue) public busQueues;
    // ID of the "open" (i.e. latest) queue
    uint32 public curQueueId;

    function addUtxosToBatch(bytes32[] memory utxos, uint96 reward) internal {
        uint32 queueId = curQueueId;
        BusQueue memory queue = busQueues[queueId];

        for (uint256 n = 0; n < utxos.length; n++) {
            bytes32 utxo = utxos[n];
            require(uint256(utxo) < FIELD_SIZE, "BQ:TOO_LARGE_COMMITMENT");
            queue.commitment = insertLeaf(
                utxo,
                queue.commitment,
                queue.nUtxos == 0
            );
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

                busQueues[queueId] = queue;
                emit BusQueueClosed(queueId, queue.nUtxos, queue.reward);

                (queueId, queue) = openNewBusQueue();
            }
        }

        if (queue.nUtxos > 0) {
            queue.reward += reward;
            busQueues[queueId] = queue;
            emit BusQueueExtended(queueId, queue.nUtxos, queue.reward);
        }
    }

    function markQueueAsOnboarded(uint32 queueId, uint256 firstIndex)
        internal
        returns (uint256 reward)
    {
        uint8 nUtxos;
        (nUtxos, reward) = ensureQueueExists(queueId);

        busQueues[queueId] = BusQueue(0, 0, 0);

        emit BusQueueOnboarded(queueId, nUtxos, firstIndex);
    }

    function registerExtraReward(uint32 queueId, uint96 extraReward) internal {
        require(extraReward > 0, "BQ:ZERO_REWARD");
        (, uint96 reward) = ensureQueueExists(queueId);

        uint96 accumReward = reward + extraReward;
        busQueues[queueId].reward = accumReward;

        emit BusQueueRewardAdded(queueId, accumReward);
    }

    function openNewBusQueue()
        private
        returns (uint32 newQueueId, BusQueue memory queue)
    {
        unchecked {
            // (Theoretical) overflow is acceptable
            newQueueId = curQueueId + 1;
        }
        curQueueId = newQueueId;
        queue = BusQueue(0, 0, 0);
        // New storage slots contains zeros, so
        // no extra initialization for `busQueues[newQueueId]` needed

        emit BusQueueOpened(newQueueId);
    }

    function ensureQueueExists(uint32 queueId)
        private
        view
        returns (uint8 nUtxos, uint96 reward)
    {
        nUtxos = busQueues[queueId].nUtxos;
        reward = busQueues[queueId].reward;
        require(nUtxos > 0, "BQ:EMPTY_QUEUE");
    }
}
