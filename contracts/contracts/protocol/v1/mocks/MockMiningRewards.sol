// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../trees/facets/forestTrees/busTree/MiningRewards.sol";

contract MockMiningRewards is MiningRewards {
    constructor(
        address feeMaster,
        address rewardToken,
        uint8 miningRewardVersion
    ) MiningRewards(feeMaster, rewardToken, miningRewardVersion) {}

    function internalAccountMinerRewards(
        uint32 queueId,
        address miner,
        uint256 reward
    ) external {
        _accountMinerRewards(queueId, miner, reward);
    }

    function internalClaimMinerRewards(
        address miner,
        address receiver
    ) external {
        _claimMinerRewards(miner, receiver);
    }
}
