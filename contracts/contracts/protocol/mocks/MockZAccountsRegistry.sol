// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../ZAccountsRegistry.sol";

contract MockZAccountsRegistry is ZAccountsRegistry {
    uint256 public nextId;

    constructor(address pantherPool, address onboardingRewardController)
        ZAccountsRegistry(msg.sender, pantherPool, onboardingRewardController)
    {}

    function mockZAccountIdTracker(uint256 _zAccountIdTracker) external {
        zAccountIdTracker = _zAccountIdTracker;
    }

    function internalGetNextZAccountId() external {
        nextId = _getNextZAccountId();
    }
}
