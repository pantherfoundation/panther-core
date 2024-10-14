// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../trees/facets/forestTrees/busTree/BusQueues.sol";

contract MockBusQueues is BusQueues {
    event LogComputedReward(uint256 reward);
    event LogQueueIdAndFirstIndex(uint32 id, uint8 firstIndexInFirstQueue);
    event LogNewBusQueue(BusQueue queue);

    function getNextQueueId() external view returns (uint256) {
        return _nextQueueId;
    }

    function getRewardReserve() external view returns (uint96) {
        return _rewardReserve;
    }

    function getNumPendingQueues() external view returns (uint256) {
        return _numPendingQueues;
    }

    function getOldestPendingQueueLink() external view returns (uint256) {
        return _oldestPendingQueueLink;
    }

    function mockSetRewardReserve(uint96 rewardReserve) external {
        _rewardReserve = rewardReserve;
    }

    function mockAddQueue(BusQueue calldata queue, uint32 id) external {
        _busQueues[id] = queue;
    }

    function internalUpdateBusQueueRewardParams(
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external {
        _updateBusQueueRewardParams(
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );
    }

    function internalAddUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 reward
    ) external returns (uint32 firstQueueId, uint8 firstIndexInFirstQueue) {
        (firstQueueId, firstIndexInFirstQueue) = _addUtxosToBusQueue(
            utxos,
            reward
        );

        emit LogQueueIdAndFirstIndex(firstQueueId, firstIndexInFirstQueue);
    }

    function internalSetBusQueueAsProcessed(
        uint32 queueId
    ) external returns (bytes32 commitment, uint8 nUtxos, uint96 reward) {
        (commitment, nUtxos, reward) = _setBusQueueAsProcessed(queueId);
    }

    function internalAddBusQueueReward(
        uint32 queueId,
        uint96 extraReward
    ) external {
        _addBusQueueReward(queueId, extraReward);
    }

    function internalCreateNewBusQueue()
        external
        returns (uint32 newQueueId, BusQueue memory queue, bytes32 commitment)
    {
        (newQueueId, queue, commitment) = _createNewBusQueue();

        emit LogNewBusQueue(queue);
    }

    function internalGetQueueRemainingBlocks(
        BusQueue memory queue
    ) external view returns (uint40) {
        return _getQueueRemainingBlocks(queue);
    }

    function internalComputeReward(
        BusQueue memory queue
    ) external returns (uint256 actReward) {
        actReward = _computeReward(queue);
        emit LogComputedReward(actReward);
    }

    function internalEstimateRewarding(
        BusQueue memory queue
    )
        external
        view
        returns (uint256 reward, uint256 premium, int256 netReserveChange)
    {
        (reward, premium, netReserveChange) = _estimateRewarding(queue);
    }
}
