// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IPantherTaxiTree {
    function addUtxo(bytes32 utxo) external;

    function addThreeUtxos(
        bytes32 utxo0,
        bytes32 utxo1,
        bytes32 utxo2
    ) external;
}
