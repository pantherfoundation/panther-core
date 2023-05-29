// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

struct BinaryTree {
    uint8 depth;
    uint32 nLeafs;
    bytes32 root;
}

struct DegenerateBinaryTree {
    uint8 maxNLeafs;
    uint8 nLeafs;
    bytes32 root;
}
