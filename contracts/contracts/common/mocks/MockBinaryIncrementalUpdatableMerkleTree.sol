// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import "../binaryTree/BinaryIncrementalUpdatableMerkleTree.sol";

contract MockBinaryIncrementalUpdatableMerkleTree is
    BinaryIncrementalUpdatableMerkleTree
{
    function internalFilledSubtrees(
        uint256 level
    ) external view returns (bytes32[2] memory) {
        return _filledSubtrees[level];
    }

    function internalInsert(bytes32 leaf) external returns (uint256) {
        return insert(leaf);
    }
}
