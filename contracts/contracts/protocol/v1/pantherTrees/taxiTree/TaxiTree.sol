// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../interfaces/ITreeRootUpdater.sol";

import "../zeroTrees/EightLevelZeroTree.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

/**
 * @title TaxiTree
 * @notice This contract manages the insertion of leaves into a Merkle tree with 8 levels,
 *  switching between two primary subtrees (with depth of 7) and resetting them as needed.
 * @dev Implements a ring buffer-based incremental Merkle tree with 8 levels (256 leaves).
 *  The tree is divided into two immutable subtrees (a.k.a primary subtree), each with 128 leaves.
 *  When the left subtree is full, the process switches to the right subtree and the root of
 *  the left subtree is remembered. When the right subtree is full, the left subtree is reset
 *  to an empty state (while remembering the root of the right subtree) and refilled.
 *  This process continues in a loop, alternating between the two subtrees and always maintaining
 *  the roots of the last filled subtrees.
 *
 * [root]                            0 (TaxiTree root)
 *                                           |
 * [7]       0 (primary subtree node) --------------- 1 (primary subtree node)
 *                            |                                |
 * [6]                0---------------1                 2--------------3
 *                    |               |                 |              |
 * [5]            0-------1       2-------3        4-------5       6-------7
 *               / \     / \     / \     / \      / \     / \     / \     / \
 * [4]          0   1   2   3   4   5   6   7    8   9  10  11   12  13  14  15
 *
 * [3 to 1]    . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
 *
 * [0]       0.............................127 128..............................255
 *
 */
abstract contract TaxiTree is EightLevelZeroTree {
    // the depth of the tree
    uint256 private constant TREE_DEPTH = EIGHT_LEVELS;
    // the index of the primary subtree root
    uint256 private constant PRIMARY_SUBTREE_DEPTH = TREE_DEPTH - 1;
    // max number of leaves per primary subtree
    uint256 internal constant MAX_LEAF_NUM = 2 ** PRIMARY_SUBTREE_DEPTH;
    // max number of leaf index in the primary subtree
    uint256 internal constant MAX_LEAF_INDEX = MAX_LEAF_NUM - 1;

    // nodes in the current subtree tree per level
    // level index => hash
    mapping(uint256 => bytes32) private _filledSubtrees;

    // the root of the TaxiTree node at level 7 (primary subtree root)
    bytes32 private _cachedPrimarySubtreeRoot;

    // total leaves insertions
    uint256 public totalLeavesInsertions;

    event TaxiSubtreeRootUpdated(bytes32 subtreeRoot);

    function getCachedPrimarySubtreeRoot() public view returns (bytes32) {
        return
            _cachedPrimarySubtreeRoot == bytes32(0)
                ? getZeroNodeAtLevel(PRIMARY_SUBTREE_DEPTH)
                : _cachedPrimarySubtreeRoot;
    }

    /**
     * @notice Inserts a new leaf into the Merkle tree and updates the tree structure accordingly.
     * @dev This function calculates the new root of the tree after inserting the leaf.
     * @param leafIndex The index of the leaf to be inserted.
     * @param leaf The hash of the leaf to be inserted.
     * @return newRoot The new root of the Merkle tree after insertion.
     */
    function _insertLeaf(
        uint256 leafIndex,
        bytes32 leaf
    ) internal returns (bytes32 newRoot) {
        bool isLeftLeaf = leafIndex & 1 == 0;

        // leaves level
        bytes32 nodeHash;
        if (isLeftLeaf) {
            nodeHash = _hash(leaf, getZeroNodeAtLevel(0));
            _filledSubtrees[0] = leaf;
        } else nodeHash = _hash(_filledSubtrees[0], leaf);

        uint256 nodeIndex = leafIndex >> 1;

        bytes32 left;
        bytes32 right;

        for (uint256 level = 1; level < PRIMARY_SUBTREE_DEPTH; level++) {
            // if `nodeIndex` is, say, 25, over the iterations it will be:
            // 25, 12, 6, 3, 1, 0, 0 ...

            if (nodeIndex % 2 == 0) {
                // left node in the branch

                left = nodeHash;
                right = getZeroNodeAtLevel(level);

                _filledSubtrees[level] = nodeHash;
            } else {
                // right node in the branch

                left = _filledSubtrees[level];
                right = nodeHash;
            }

            nodeHash = _hash(left, right);

            // equivalent to `nodeIndex /= 2`
            nodeIndex >>= 1;
        }

        uint256 primarySubtreeIndicator = (totalLeavesInsertions /
            MAX_LEAF_NUM) & 1;

        if (primarySubtreeIndicator == 0) {
            // left subtree
            newRoot = _hash(nodeHash, getCachedPrimarySubtreeRoot());
        }
        if (primarySubtreeIndicator == 1) {
            // right subtree
            newRoot = _hash(getCachedPrimarySubtreeRoot(), nodeHash);
        }

        // update the root of primary subtree if it's full
        if (leafIndex == MAX_LEAF_INDEX) {
            _cachedPrimarySubtreeRoot = nodeHash;
            emit TaxiSubtreeRootUpdated(nodeHash);
        }
    }

    function _hash(
        bytes32 leftLeaf,
        bytes32 rightLeaf
    ) private pure returns (bytes32) {
        return PoseidonHashers.poseidonT3([leftLeaf, rightLeaf]);
    }
}
