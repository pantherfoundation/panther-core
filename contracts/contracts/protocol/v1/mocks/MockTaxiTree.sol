// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
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
