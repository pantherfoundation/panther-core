// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IOnboardingController {
    function grantRewards(
        address _user,
        uint8 prevStatus,
        uint8 newStatus,
        bytes memory _data
    ) external returns (uint256 _userZkpRewardAlloc);
}
