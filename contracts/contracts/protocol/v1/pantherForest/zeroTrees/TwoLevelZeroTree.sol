// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

// @notice The binary Merkle tree of two levels populated with zero leaf values
abstract contract TwoLevelZeroTree {
    // @dev Number of levels in a tree excluding the root level
    uint256 internal constant TWO_LEVELS = 2;

    // Root of the only branch of the 2-levels tree fully populated with zero leafs only
    bytes32 public constant ZERO_NODE =
        0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4;
}
