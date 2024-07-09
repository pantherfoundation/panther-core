// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../pantherTrees/forestTree/CachedRoots.sol";

contract MockCachedRoots is CachedRoots {
    function internalCacheNewRoot(
        bytes32 root
    ) external returns (uint256 cacheIndex) {
        return cacheNewRoot(root);
    }
}
