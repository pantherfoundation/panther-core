// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../PantherTaxiTree.sol";
import "../pantherForest/interfaces/ITreeRootUpdater.sol";
import "../pantherForest/interfaces/ITreeRootGetter.sol";

contract MockPantherTaxiTreeOwner is ITreeRootUpdater {
    PantherTaxiTree public pantherTaxiTree;

    constructor() {
        pantherTaxiTree = new PantherTaxiTree(address(this));
    }

    function addUtxo(bytes32 utxo) external {
        pantherTaxiTree.addUtxo(utxo);
    }

    function addThreeUtxos(
        bytes32 utxo0,
        bytes32 utxo1,
        bytes32 utxo2
    ) external {
        pantherTaxiTree.addThreeUtxos(utxo0, utxo1, utxo2);
    }

    function getTaxiTreeRoot() external view returns (bytes32) {
        return pantherTaxiTree.getRoot();
    }

    // solhint-disable-next-line no-empty-blocks
    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external {}
}
