// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./BinaryIncrementalTree.sol";

abstract contract BinaryUpdatableTree is BinaryIncrementalTree {
    function updateLeaf(
        BinaryTree storage tree,
        bytes32 newLeaf,
        bytes32 oldLeaf,
        uint256 leafInd,
        bytes32[] memory siblings
    ) internal returns (bytes32 newRoot) {
        // TODO: implement BinaryUpdatableTree::insertLeaf
        return 0;
    }
}
