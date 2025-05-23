// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../trees/facets/forestTrees/BusTree.sol";

contract MockBusTree is BusTree {
    event LogComputedReward(uint256 reward);
    event LogQueueIdAndFirstIndex(uint32 id, uint8 firstIndexInFirstQueue);
    event LogNewBusQueue(BusQueue queue);

    constructor(
        address feeMaster,
        address rewardToken,
        uint8 miningRewardVersion
    ) BusTree(feeMaster, rewardToken, miningRewardVersion) {}

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

    function getInternalSlots()
        external
        view
        returns (
            uint256 nextQueueId,
            uint96 rewardReserve,
            uint256 numPendingQueues,
            uint256 oldestPendingQueueLink
        )
    {
        nextQueueId = _nextQueueId;
        rewardReserve = _rewardReserve;
        numPendingQueues = _numPendingQueues;
        oldestPendingQueueLink = _oldestPendingQueueLink;
    }

    function mockSetRewardReserve(uint96 rewardReserve) external {
        _rewardReserve = rewardReserve;
    }

    function mockAddQueue(BusQueue calldata queue, uint32 id) external {
        _busQueues[id] = queue;
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

    function internalOnboardQueueAndAccountReward(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    ) external {
        _onboardQueueAndAccountReward(miner, queueId, inputs, proof);
    }

    function internalInitializeBusTree(
        uint160 _onboardingQueueCircuitId,
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external {
        _initializeBusTree(
            _onboardingQueueCircuitId,
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );
    }

    function internalClaimMinerRewards(
        address miner,
        address receiver
    ) external {
        _claimMinerRewards(miner, receiver);
    }

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) internal view override {} // solhint-disable-line no-empty-blocks
}
