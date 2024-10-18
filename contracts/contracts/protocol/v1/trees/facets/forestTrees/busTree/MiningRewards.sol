// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../../../interfaces/IDebtSettlement.sol";
import "../../../errMsgs/MiningRewardsErrMsgs.sol";
import "./MiningRewardsSignatureVerifier.sol";

abstract contract MiningRewards is MiningRewardsSignatureVerifier {
    // address of feeMaster contract
    address public immutable FEE_MASTER;

    // address of reward token
    address public immutable REWARD_TOKEN;

    mapping(address => uint256) public miningRewards;

    event MinerRewardAccounted(uint32 queueId, address miner, uint256 reward);
    event MinerRewardClaimed(uint32 timestamp, address miner, uint256 reward);

    constructor(
        address feeMaster,
        address rewardToken,
        uint8 miningRewardVersion
    ) MiningRewardsSignatureVerifier(miningRewardVersion) {
        FEE_MASTER = feeMaster;
        REWARD_TOKEN = rewardToken;
    }

    function _accountMinerRewards(
        uint32 queueId,
        address miner,
        uint256 reward
    ) internal {
        miningRewards[miner] += reward;
        emit MinerRewardAccounted(queueId, miner, reward);
    }

    function _claimMinerRewards(address miner, address receiver) internal {
        uint256 reward = miningRewards[miner];
        require(reward != 0, ERR_ZERO_MINER_REWARD);

        miningRewards[miner] = 0;

        _payOff(receiver, reward);

        emit MinerRewardClaimed(uint32(block.number), miner, reward);
    }

    function _payOff(address receiver, uint256 reward) private {
        try
            IDebtSettlement(FEE_MASTER).payOff(REWARD_TOKEN, receiver, reward)
        returns (
            uint256 // solhint-disable-next-line no-empty-blocks
        ) {} catch Error(string memory reason) {
            revert(reason);
        }
    }
}
