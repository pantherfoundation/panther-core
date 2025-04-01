// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../trees/facets/forestTrees/CachedRoots.sol";

contract MockCachedRoots is CachedRoots {
    function internalCacheNewForestRoot(
        bytes32 updatedLeaf,
        uint256 leafIndex
    ) public returns (bytes32) {
        return super._cacheNewForestRoot(updatedLeaf, leafIndex);
    }
}
