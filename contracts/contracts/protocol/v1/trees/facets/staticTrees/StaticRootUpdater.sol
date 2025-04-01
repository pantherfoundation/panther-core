// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../interfaces/IStaticTreeRootUpdater.sol";

abstract contract StaticRootUpdater {
    address private immutable SELF;

    constructor(address self) {
        SELF = self;
    }

    function _updateStaticRoot(bytes32 newRoot, uint256 leafIndex) internal {
        IStaticTreeRootUpdater(SELF).updateStaticRoot(newRoot, leafIndex);
    }
}
