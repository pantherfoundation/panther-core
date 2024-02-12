// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IProtocolRewardController {
    function vestRewards() external returns (uint256 releasable);
}
