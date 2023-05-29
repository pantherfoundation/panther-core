// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

// @dev Leaf zero value (`keccak256("Pantherprotocol")%FIELD_SIZE`)
// TODO: remove duplications of ZERO_LEAF across ../../
bytes32 constant ZERO_VALUE = bytes32(
    uint256(0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d)
);
