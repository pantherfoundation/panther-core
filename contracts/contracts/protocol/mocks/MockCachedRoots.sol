// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../pantherForest/cachedRoots/CachedRoots.sol";

contract MockCachedRoots is CachedRoots {
    function internalCacheNewRoot(bytes32 root)
        external
        returns (uint256 cacheIndex)
    {
        return cacheNewRoot(root);
    }

    function internalResetThenCacheNewRoot(bytes32 root)
        external
        returns (uint256 cacheIndex)
    {
        return resetThenCacheNewRoot(root);
    }
}
