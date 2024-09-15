// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../interfaces/IStaticTreeRootUpdater.sol";

abstract contract StaticRootUpdater {
    address public immutable SELF;

    constructor(address self) {
        SELF = self;
    }

    function _updateStaticRoot(bytes32 newRoot, uint256 leafIndex) internal {
        IStaticTreeRootUpdater(SELF).updateStaticRoot(newRoot, leafIndex);
    }
}
