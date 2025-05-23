// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// slither-disable-next-line solc-version
pragma solidity ^0.8.4;

// The "stake type" for the "classic staking"
// bytes4(keccak256("classic"))
bytes4 constant CLASSIC_STAKE_TYPE = 0x4ab0941a;

// STAKE "action type" for the "classic staking"
// bytes4(keccak256(abi.encodePacked(bytes4(keccak256("stake"), CLASSIC_STAKE_TYPE)))
bytes4 constant CLASSIC_STAKE = 0x1e4d02b5;

// UNSTAKE "action type" for the "classic staking"
// bytes4(keccak256(abi.encodePacked(bytes4(keccak256("unstake"), CLASSIC_STAKE_TYPE)))
bytes4 constant CLASSIC_UNSTAKE = 0x493bdf45;

// The "stake type" for the "advance staking"
// bytes4(keccak256("advanced"))
bytes4 constant ADVANCED_STAKE_TYPE = 0x7ec13a06;

// STAKE "action type" for the "advanced staking"
// bytes4(keccak256(abi.encodePacked(bytes4(keccak256("stake"), ADVANCED_STAKE_TYPE)))
bytes4 constant ADVANCED_STAKE = 0xcc995ce8;

// UNSTAKE "action type" for the "advanced staking"
// bytes4(keccak256(abi.encodePacked(bytes4(keccak256("unstake"), ADVANCED_STAKE_TYPE)))
bytes4 constant ADVANCED_UNSTAKE = 0xb8372e55;

// The "stake type" for the "advance staking"
// bytes4(keccak256("advanced-v2"))
bytes4 constant ADVANCED_STAKE_V2_TYPE = 0x8496de05;

// STAKE "action type" for the "advanced staking V2"
// bytes4(keccak256(abi.encodePacked(bytes4(keccak256("stake"), ADVANCED_STAKE_V2_TYPE)))
bytes4 constant ADVANCED_STAKE_V2 = 0x1954e321;

// UNSTAKE "action type" for the "advanced staking v2"
// bytes4(keccak256(abi.encodePacked(bytes4(keccak256("unstake"), ADVANCED_STAKE_V2_TYPE)))
bytes4 constant ADVANCED_UNSTAKE_V2 = 0x6a8ecb81;

// PRP grant type for the "advanced" stake
// bytes4(keccak256("forAdvancedStakeGrant"))
bytes4 constant FOR_ADVANCED_STAKE_GRANT = 0x31a180d4;
