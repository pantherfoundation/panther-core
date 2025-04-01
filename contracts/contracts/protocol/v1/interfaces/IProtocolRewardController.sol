// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IProtocolRewardController {
    function vestRewards() external returns (uint256 releasable);
}
