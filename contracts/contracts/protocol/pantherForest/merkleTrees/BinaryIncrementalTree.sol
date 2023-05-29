// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { BinaryTree } from "./Types.sol";

abstract contract BinaryIncrementalTree {
    function insertLeafs(BinaryTree storage tree, bytes32[] memory leafs)
        internal
        returns (uint256 firstLeafIndex, bytes32 newRoot)
    {
        return (0, 0);
    }

    function insertLeaf(BinaryTree storage tree, bytes32 leaf)
        internal
        returns (uint256 leafIndex, bytes32 newRoot)
    {
        return (0, 0);
    }

    function hash(bytes32[2] memory) internal view virtual returns (bytes32);
}
