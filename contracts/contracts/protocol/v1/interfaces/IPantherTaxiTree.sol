// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IPantherTaxiTree {
    function addUtxo(bytes32 utxo) external;

    function addUtxos(bytes32 utxo0, bytes32 utxo1, bytes32 utxo2) external;
}
