// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../trees/facets/forestTrees/TaxiTree.sol";

contract MockTaxiTree is TaxiTree {
    function addUtxos(
        bytes32[] memory utxos
    ) external returns (bytes32 newRoot) {
        return _addUtxos(utxos);
    }

    function addUtxo(bytes32 utxo) external returns (bytes32 newRoot) {
        return _addUtxo(utxo);
    }
}
