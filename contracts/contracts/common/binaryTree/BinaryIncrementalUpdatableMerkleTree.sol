// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./BinaryMerkleZeros.sol";
import "../../protocol/triadTree/Hasher.sol";

/**
 * @title BinaryIncrementalUpdatableMerkleTree
 * @notice
 * @dev
 */
abstract contract BinaryIncrementalUpdatableMerkleTree is
    BinaryMerkleZeros,
    Hasher
{
    // `index` of the next leaf to insert
    // !!! NEVER access it directly from child contracts: `internal` to ease testing only
    uint256 internal _nextLeafIndex;

    // The nodes of the subtrees used in the last addition of a leaf (level -> [left node, right node])
    mapping(uint256 => bytes32[2]) internal _filledSubtrees;

    uint256 public constant LEAVES_NUM = 2 ** TREE_DEPTH;

    bytes32 public currentRoot;

    /**
     * @dev Inserts a leaf into the tree if it's not yet full
     * @param leaf The leaf to be inserted
     * @return insertedLeafIndex The leaf index which has been inserted
     */
    function insert(bytes32 leaf) internal returns (uint256 insertedLeafIndex) {
        uint256 index = _nextLeafIndex;
        require(index < LEAVES_NUM, "BIUT: Tree is full");

        // here the variable is intentionally declared only ...
        // slither-disable-next-line uninitialized-local
        bytes32[TREE_DEPTH] memory zeros;
        // ... and initialized in this call
        populateZeros(zeros);

        bytes32 left;
        bytes32 right;
        bytes32 _hash = leaf;

        for (uint8 level = 0; level < TREE_DEPTH; ) {
            if (index % 2 == 0) {
                left = _hash;
                right = zeros[level];

                _filledSubtrees[level] = [left, right];
            } else {
                left = _filledSubtrees[level][0];
                right = _hash;

                _filledSubtrees[level][1] = right;
            }

            _hash = hash(left, right);
            index >>= 1;

            unchecked {
                ++level;
            }
        }

        currentRoot = _hash;
        insertedLeafIndex = _nextLeafIndex;
        _nextLeafIndex++;
    }

    /**
     * @dev Update an existing leaf
     * @param leaf Leaf to be updated.
     * @param newLeaf New leaf.
     * @param proofSiblings Array of the sibling nodes of the proof of membership.
     * @param proofPathIndices Path of the proof of membership.
     * @return _hash The new root after updating the tree
     */
    function update(
        bytes32 leaf,
        bytes32 newLeaf,
        bytes32[] calldata proofSiblings,
        uint8[] calldata proofPathIndices
    ) internal returns (bytes32 _hash) {
        require(newLeaf != leaf, "BIUT: New leaf cannot be equal the old one");
        require(
            verify(leaf, proofSiblings, proofPathIndices),
            "BIUT: Leaf is not part of the tree"
        );

        _hash = newLeaf;
        uint256 updateIndex;

        for (uint256 i = 0; i < TREE_DEPTH; ) {
            updateIndex |= uint256(proofPathIndices[i]) << uint256(i);

            if (proofPathIndices[i] == 0) {
                if (proofSiblings[i] == _filledSubtrees[i][1]) {
                    _filledSubtrees[i][0] = _hash;
                }

                _hash = hash(_hash, proofSiblings[i]);
            } else {
                if (proofSiblings[i] == _filledSubtrees[i][0]) {
                    _filledSubtrees[i][1] = _hash;
                }

                _hash = hash(proofSiblings[i], _hash);
            }

            unchecked {
                ++i;
            }
        }

        require(updateIndex < LEAVES_NUM, "BIUT: Leaf index out of range");

        currentRoot = _hash;
    }

    /**
     * @dev Verify if the path is correct and the leaf is part of the tree.
     * @param leaf Leaf to be updated.
     * @param proofSiblings Array of the sibling nodes of the proof of membership.
     * @param proofPathIndices Path of the proof of membership.
     * @return True or false.
     */
    function verify(
        bytes32 leaf,
        bytes32[] calldata proofSiblings,
        uint8[] calldata proofPathIndices
    ) internal view returns (bool) {
        require(
            proofPathIndices.length == TREE_DEPTH &&
                proofSiblings.length == TREE_DEPTH,
            "BIUT: length of path is not correct"
        );

        bytes32 _hash = leaf;

        for (uint256 i = 0; i < TREE_DEPTH; ) {
            require(
                proofPathIndices[i] == 1 || proofPathIndices[i] == 0,
                "IncrementalBinaryTree: path index is neither 0 nor 1"
            );

            if (proofPathIndices[i] == 0) {
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

    /**
     * @dev Gettign the next leaf index
     * @return the leaf index
     */
    function getNextLeafIndex() external view returns (uint256) {
        return uint256(_nextLeafIndex);
    }
}
