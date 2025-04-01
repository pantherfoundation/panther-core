// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// @notice The "binary binary tree" populated with zero leaf values

/**
 * @title BinaryIncrementalUpdatableMerkleTree
 * @notice
 * @dev
 */
abstract contract BinaryUpdatableTree {
    /**
     * @dev Update an existing leaf
     * @param curRoot current merkle root.
     * @param leaf Leaf to be updated.
     * @param newLeaf New leaf.
     * @param leafIndex leafIndex
     * @param proofSiblings Path of the proof of membership.
     * @return _newRoot The new root after updating the tree
     */
    function update(
        bytes32 curRoot,
        bytes32 leaf,
        bytes32 newLeaf,
        uint256 leafIndex,
        bytes32[] memory proofSiblings
    ) internal pure returns (bytes32 _newRoot) {
        require(newLeaf != leaf, "BIUT: New leaf cannot be equal the old one");
        require(
            verify(curRoot, leaf, leafIndex, proofSiblings),
            "BIUT: Leaf is not part of the tree"
        );

        _newRoot = newLeaf;
        uint256 proofPathIndice;

        // using `proofSiblings[]` length as the tree dept
        for (uint256 i = 0; i < proofSiblings.length; ) {
            // getting the bit at position `i` and check if it's 0 or 1
            proofPathIndice = (leafIndex >> i) & 1;

            if (proofPathIndice == 0) {
                _newRoot = hash([_newRoot, proofSiblings[i]]);
            } else {
                _newRoot = hash([proofSiblings[i], _newRoot]);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Verify if the path is correct and the leaf is part of the tree.
     * @param curRoot current merkle root.
     * @param leaf Leaf to be updated.
     * @param leafIndex leafIndex
     * @param proofSiblings Path of the proof of membership.
     * @return True or false.
     */
    function verify(
        bytes32 curRoot,
        bytes32 leaf,
        uint256 leafIndex,
        bytes32[] memory proofSiblings
    ) internal pure returns (bool) {
        // equal to 2**proofSiblings.length
        uint256 leavesNum = 1 << proofSiblings.length;
        require(leafIndex < leavesNum, "BIUT: invalid leaf index");

        bytes32 _hash = leaf;
        uint256 proofPathIndice;

        // using `proofSiblings[]` length as the tree dept
        for (uint256 i = 0; i < proofSiblings.length; ) {
            // getting the bit at position `i` and check if it's 0 or 1
            proofPathIndice = (leafIndex >> i) & 1;

            if (proofPathIndice == 0) {
                _hash = hash([_hash, proofSiblings[i]]);
            } else {
                _hash = hash([proofSiblings[i], _hash]);
            }

            unchecked {
                ++i;
            }
        }

        return curRoot == 0 ? _hash == zeroRoot() : _hash == curRoot;
    }

    function zeroRoot() internal pure virtual returns (bytes32);

    function hash(
        bytes32[2] memory input
    ) internal pure virtual returns (bytes32);
}
