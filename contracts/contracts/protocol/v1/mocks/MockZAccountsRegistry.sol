// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../ZAccountsRegistry.sol";

contract MockZAccountsRegistry is ZAccountsRegistry {
    uint256 public nextId;

    constructor(
        uint8 _zAccountVersion,
        address pantherPool,
        address pantherStaticTree,
        address onboardingRewardController
    )
        ZAccountsRegistry(
            msg.sender,
            _zAccountVersion,
            pantherPool,
            pantherStaticTree,
            onboardingRewardController
        )
    {} // solhint-disable-line no-empty-blocks

    function mockZAccountIdTracker(uint256 _zAccountIdTracker) external {
        zAccountIdTracker = _zAccountIdTracker;
    }

    function internalGetNextZAccountId() external {
        nextId = _getNextZAccountId();
    }
}
