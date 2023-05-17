// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IProtocolRewardController {
    function vestRewards() external returns (uint256 releasable);
}
