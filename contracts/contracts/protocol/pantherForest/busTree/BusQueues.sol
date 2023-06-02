// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../merkleTrees/DegenerateIncrementalBinaryTree.sol";

abstract contract BusQueues is DegenerateIncrementalBinaryTree {
    uint256 internal constant QUEUE_SIZE_BIT = 6;
    uint256 internal constant QUEUE_SIZE = 2**QUEUE_SIZE_BIT;

    struct BusQueue {
        bytes32 commitment;
        uint8 nUtxos;
        uint96 reward;
    }

    event BusQueueOpened(uint256 queueId);
    event BusQueueOnboarded(
        uint256 indexed queueId,
        uint256 nUtxos,
        uint256 firstIndex
    );
    event BusQueueRevalued(uint256 queueId, uint256 accumReward);
    event UtxoBusQueued(bytes32 indexed utxo, uint256 queueId, uint256 index);

    // Mapping from queue ID to queue params
    mapping(uint32 => BusQueue) public busQueues;
    // ID of the "open" (i.e. latest) queue
    uint32 public curQueueId;

    function addUtxosToBatch(bytes32[] memory utxos, uint96 reward) internal {
        uint32 queueId = curQueueId;
        BusQueue memory queue = busQueues[queueId];
        uint8 firstUtxoInd = queue.nUtxos;

        bool isNewBusQueue = firstUtxoInd == 0;
        for (uint256 n = 0; n < utxos.length; n++) {
            bytes32 utxo = utxos[n];
            queue.commitment = insertLeaf(
                utxo,
                queue.commitment,
                isNewBusQueue && n == 0
            );
            emit UtxoBusQueued(utxos[n], queueId, queue.nUtxos);
            queue.nUtxos += 1;
            if (queue.nUtxos == QUEUE_SIZE) openNewBusQueue();
        }
        if (reward > 0) {
            queue.reward += reward;
            emit BusQueueRevalued(queueId, queue.reward);
        }
        busQueues[queueId] = queue;
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

        emit BusQueueRevalued(queueId, accumReward);
    }

    function openNewBusQueue() private {
        uint32 queueId;
        unchecked {
            // (Theoretical) overflow is acceptable
            queueId = curQueueId + 1;
        }
        curQueueId = queueId;
        // New storage slots contains zeros, so
        // no extra initialization for `busQueues[queueId]` needed
        emit BusQueueOpened(queueId);
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
