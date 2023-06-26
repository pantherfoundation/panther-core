// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * Example:
 * [4]                                       0
 *                                           |
 * [3]                        0--------------------------------1
 *                            |                                |
 * [2]                0---------------1                 2--------------3
 *                    |               |                 |              |
 * [1]            0-------1       2-------3        4-------5       6-------7
 *               / \     / \     / \     / \      / \     / \     / \     / \
 * [0] index:   0   1   2   3   4   5   6   7    8   9   10 11   12 13   14 15
 *
 *   leaf ID:   0...1   2...3   4...5   6...7    8...8   10..11  12..13  14..15
 *
 * - Number in [] is the "level index" that starts from 0 for the leaves level.
 * - Numbers in node/leaf positions are "node/leaf indices" which starts from 0
 *   for the leftmost node/leaf of every level.
 * - Numbers bellow leaves are IDs of leaves.


'0x0000000000000000000000000000000000000000000000000000000000000000'   Level 0
'0x2098f5fb9e239eab3ceac3f27b81e481dc3124d55ffed523a839ee8446b64864'   Level 1 
'0x1069673dcdb12263df301a6ff584a7ec261a44cb9dc68df067a4774460b1f1e1'   Level 2
'0x18f43331537ee2af2e3d758d50f72106467c6eea50371dd528d57eb2b856d238'   Level 3
'0x07f9d837cb17b0d36320ffe93ba52345f1b728571a568265caac97559dbc952a'   Level 4
'0x2b94cf5e8746b3f5c9631f4c5df32907a699c58c94b2ad4d7b5cec1639183f55'   Level 5
'0x2dee93c5a666459646ea7d22cca9e1bcfed71e6951b953611d11dda32ea09d78'   Level 6
'0x078295e5a22b84e982cf601eb639597b8b0515a88cb5ac7fa8a4aabe3c87349d'   Level 7
'0x2fa5e5f18f6027a6501bec864564472a616b2e274a41211a444cbe3a99f3cc61'   Level 8
'0x0e884376d0d8fd21ecb780389e941f66e45e7acce3e228ab3e2156a614fcd747'   Level 9
'0x1b7201da72494f1e28717ad1a52eb469f95892f957713533de6175e5da190af2'   Level 10
'0x1f8d8822725e36385200c0b201249819a6e6e1e4650808b5bebc6bface7d7636'   Level 11
'0x2c5d82f66c914bafb9701589ba8cfcfb6162b0a12acf88a8d0879a0471b5f85a'   Level 12
'0x14c54148a0940bb820957f5adf3fa1134ef5c4aaa113f4646458f270e0bfbfd0'   Level 13
'0x190d33b12f986f961e10c0ee44d8b9af11be25588cad89d416118e4bf4ebe80c'   Level 14
'0x22f98aa9ce704152ac17354914ad73ed1167ae6596af510aa5b3649325e06c92'   Level 15

'0x2a7c7c9b6ce5880b9f6f228d72bf6a575a526f29c66ecceef8b753d38bba7323'   Root

 */

// @notice The "binary binary tree" populated with zero leaf values

/**
 * @title BinaryIncrementalUpdatableMerkleTree
 * @notice
 * @dev
 */
abstract contract BinaryUpdatableMerkleTree {
    // The nodes of the subtrees used in the last addition of a leaf (level -> [left node, right node])
    mapping(uint256 => bytes32[2]) internal _filledSubtrees;

    // @dev Number of levels in a tree excluding the root level
    uint256 internal constant TREE_DEPTH = 16;

    uint256 public constant LEAVES_NUM = 2**TREE_DEPTH;

    bytes32 public currentRoot =
        bytes32(
            uint256(
                0x2a7c7c9b6ce5880b9f6f228d72bf6a575a526f29c66ecceef8b753d38bba7323
            )
        );

    /**
     * @dev Update an existing leaf
     * @param leaf Leaf to be updated.
     * @param newLeaf New leaf.
     * @param leafIndex leafIndex
     * @param proofSiblings Path of the proof of membership.
     * @return _hash The new root after updating the tree
     */
    function update(
        bytes32 leaf,
        bytes32 newLeaf,
        uint256 leafIndex,
        bytes32[] memory proofSiblings
    ) internal returns (bytes32 _hash) {
        require(newLeaf != leaf, "BIUT: New leaf cannot be equal the old one");
        require(
            verify(leaf, leafIndex, proofSiblings),
            "BIUT: Leaf is not part of the tree"
        );

        _hash = newLeaf;
        uint256 proofPathIndice;

        for (uint256 i = 0; i < TREE_DEPTH; ) {
            // getting the bit at position `i` and check if it's 0 or 1
            proofPathIndice = (leafIndex >> i) & 1;

            if (proofPathIndice == 0) {
                _hash = hash(_hash, proofSiblings[i]);
            } else {
                _hash = hash(proofSiblings[i], _hash);
            }

            unchecked {
                ++i;
            }
        }

        currentRoot = _hash;
    }

    /**
     * @dev Verify if the path is correct and the leaf is part of the tree.
     * @param leaf Leaf to be updated.
     * @param leafIndex leafIndex
     * @param proofSiblings Path of the proof of membership.
     * @return True or false.
     */
    function verify(
        bytes32 leaf,
        uint256 leafIndex,
        bytes32[] memory proofSiblings
    ) internal view returns (bool) {
        require(
            proofSiblings.length == TREE_DEPTH,
            "BIUT: length of path is not correct"
        );
        require(leafIndex < LEAVES_NUM, "BIUT: invalid leaf index");

        bytes32 _hash = leaf;
        uint256 proofPathIndice;

        for (uint256 i = 0; i < TREE_DEPTH; ) {
            // getting the bit at position `i` and check if it's 0 or 1
            proofPathIndice = (leafIndex >> i) & 1;

            if (proofPathIndice == 0) {
                _hash = hash(_hash, proofSiblings[i]);
            } else {
                _hash = hash(proofSiblings[i], _hash);
            }

            unchecked {
                ++i;
            }
        }

        return _hash == currentRoot;
    }

    function hash(bytes32 left, bytes32 right)
        internal
        pure
        virtual
        returns (bytes32);
}
