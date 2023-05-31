// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

struct BinaryTree {
    uint8 depth;
    uint32 nLeafs;
    bytes32 root;
}

abstract contract BinaryIncrementalTree {
    function insertLeafs(BinaryTree storage tree, bytes32[] memory leafs)
        internal
        returns (uint256 firstLeafIndex, bytes32 newRoot)
    {
        // TODO: implement BinaryIncrementalTree::insertLeafs
        return (0, 0);
    }

    function insertLeaf(BinaryTree storage tree, bytes32 leaf)
        internal
        returns (uint256 leafIndex, bytes32 newRoot)
    {
        // TODO: implement BinaryIncrementalTree::insertLeaf
        return (0, 0);
    }

    function hash(bytes32[2] memory) internal view virtual returns (bytes32);
}
