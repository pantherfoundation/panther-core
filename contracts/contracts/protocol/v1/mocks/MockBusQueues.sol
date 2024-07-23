// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../pantherTrees/busTree/BusQueues.sol";

contract MockBusQueues is BusQueues {
    event logComputedReward(uint256 reward);

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
        emit logComputedReward(actReward);
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

    function setRewardReserve(uint96 rewardReserve) external {
        _rewardReserve = rewardReserve;
    }

    function getRewardReserve() external view returns (uint256) {
        return _rewardReserve;
    }
}
