// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { SnarkProof } from "../../common/Types.sol";

interface IOnboardingRewardController {
    function grantRewards(address _user, address _kycProvider)
        external
        returns (uint256 _userZkpRewardAlloc);
}
