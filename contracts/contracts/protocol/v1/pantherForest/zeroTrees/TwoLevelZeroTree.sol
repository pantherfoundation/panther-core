// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// @notice The binary Merkle tree of two levels populated with zero leaf values
abstract contract TwoLevelZeroTree {
    // @dev The inner node of the 2-level tree populated with 4 zero leafs
    bytes32 public constant ZERO_NODE =
        0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4;
}
