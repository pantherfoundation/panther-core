// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

/**
 * @dev It computes the root of the degenerate binary merkle tree
 * - i.e. for the tree of this kind (_tree.nLeafs is 4 here):
 *     root
 *      /\
 *     /\ 3
 *    /\ 2
 *   0  1
 * If the tree has just a single leaf, it's root equals to the leaf.
 */
abstract contract DegenerateIncrementalBinaryTree {
    function insertLeaf(
        bytes32 leaf,
        bytes32 root,
        bool isFirstLeaf
    ) internal pure returns (bytes32 newRoot) {
        newRoot = isFirstLeaf ? leaf : hash(root, leaf);
    }

    function hash(bytes32 left, bytes32 right)
        internal
        pure
        virtual
        returns (bytes32);
}
