// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../core/facets/ZAccountsRegistration.sol";

contract MockZAccountsRegistration is ZAccountsRegistration {
    uint256 public nextId;

    constructor(
        uint8 _zAccountVersion,
        address prpVoucherGrantor,
        address pantherTrees,
        address feeMaster,
        address zkpToken
    )
        ZAccountsRegistration(
            _zAccountVersion,
            prpVoucherGrantor,
            pantherTrees,
            feeMaster,
            zkpToken
        )
    {} // solhint-disable-line no-empty-blocks

    function mockZAccountIdTracker(uint256 _zAccountIdTracker) external {
        zAccountIdTracker = _zAccountIdTracker;
    }

    function internalGetNextZAccountId() external {
        nextId = _getNextZAccountId();
    }

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) public view override {} // solhint-disable-line no-empty-blocks
}
