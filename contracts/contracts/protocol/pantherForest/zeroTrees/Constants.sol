// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

// @dev Leaf zero value (`keccak256("Pantherprotocol")%FIELD_SIZE`)
// TODO: remove duplications of ZERO_LEAF across ../../
bytes32 constant ZERO_VALUE = bytes32(
    uint256(0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d)
);

// @dev Number of levels (bellow the root, but including leafs) in the BusTree
uint256 constant BUS_TREE_LEVELS = 26;

// @dev Root of the binary tree of BUS_TREE_LEVELS with leafs of ZERO_VALUE
// Computed using `../../../../lib/binaryMerkleZerosContractGenerator.ts`
bytes32 constant EMPTY_BUS_TREE_ROOT = bytes32(
    uint256(0x1bdded415724018275c7fcc2f564f64db01b5bbeb06d65700564b05c3c59c9e6)
);
