// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../ZAccountsRegistry.sol";

contract MockZAccountsRegistry is ZAccountsRegistry {
    uint256 public nextId;

    constructor(
        uint8 _zAccountVersion,
        address pantherPool,
        address pantherStaticTree,
        address prpVoucherGrantor
    )
        ZAccountsRegistry(
            msg.sender,
            _zAccountVersion,
            pantherPool,
            pantherStaticTree,
            prpVoucherGrantor
        )
    {} // solhint-disable-line no-empty-blocks

    function mockZAccountIdTracker(uint256 _zAccountIdTracker) external {
        zAccountIdTracker = _zAccountIdTracker;
    }

    function internalGetNextZAccountId() external {
        nextId = _getNextZAccountId();
    }
}
