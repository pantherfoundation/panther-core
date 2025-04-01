// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
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
