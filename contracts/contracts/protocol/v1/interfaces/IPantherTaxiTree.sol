// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IPantherTaxiTree {
    function addUtxos(bytes32[] calldata utxos) external;

    function addUtxo(bytes32 utxo) external;
}
