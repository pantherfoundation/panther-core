// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
// solhint-disable var-name-mixedcase
pragma solidity ^0.8.16;

// TODO: remove FIELD_SIZE duplicated definitions ("import" from here instead)
// @dev Order of alt_bn128 and the field prime of Baby Jubjub and Poseidon hash
uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

// @dev Field prime of alt_bn128
uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

// FIXME: make MAGICAL_CONSTRAINT the public input (var, not const) - it MUST have random value on every invocation
// @dev Circuit extra public input as work-around for recently found groth16 vulnerability
uint256 constant MAGICAL_CONSTRAINT = 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00;
