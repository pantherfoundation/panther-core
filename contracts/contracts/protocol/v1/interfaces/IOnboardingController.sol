// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

interface IOnboardingController {
    function grantRewards(
        address _user,
        uint8 prevStatus,
        uint8 newStatus,
        bytes memory _data
    ) external returns (uint256 _userZkpRewardAlloc);
}
