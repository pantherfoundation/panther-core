// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IRootsHistory {
    /// @notice Returns `true` if the given root of the given tree is known
    /// @param cacheIndexHint Index of the root in the cache, ignored if 0
    function isKnownRoot(
        uint256 treeId,
        bytes32 root,
        uint256 cacheIndexHint
    ) external view returns (bool);
}
