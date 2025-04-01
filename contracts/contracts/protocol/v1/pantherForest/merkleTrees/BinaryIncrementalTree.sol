// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

struct BinaryTree {
    uint8 depth;
    uint32 nLeafs;
    bytes32 root;
}

abstract contract BinaryIncrementalTree {
    function insertLeafs(
        BinaryTree storage /* tree */,
        bytes32[] memory /* leafs */
    ) internal returns (uint256 firstLeafIndex, bytes32 newRoot) {
        // TODO: implement BinaryIncrementalTree::insertLeafs
        return (0, 0);
    }

    function insertLeaf(
        BinaryTree storage /* tree */,
        bytes32 /* leaf */
    ) internal returns (uint256 leafIndex, bytes32 newRoot) {
        // TODO: implement BinaryIncrementalTree::insertLeaf
        return (0, 0);
    }

    function hash(bytes32[2] memory) internal view virtual returns (bytes32);
}
