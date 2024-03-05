// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IPantherTaxiTree {
    function addUtxos(bytes32[] calldata utxos) external;
}
