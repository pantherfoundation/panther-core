// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./taxiTree/RingBufferTree.sol";
import { EIGHT_LEVEL_EMPTY_TREE_ROOT } from "../../utils/zeroTrees/Constants.sol";

/**
 * @title PantherTaxiTree
 * @author Pantherprotocol Contributors
 * @dev It enables the direct insertion of an array of UTXOs into the TaxiTree.
 */
contract TaxiTree is RingBufferTree {
    bytes32 private _currentRoot;

    event TaxiRootUpdated(bytes32 updatedRoot, uint256 numLeaves);
    event TaxiUtxoAdded(bytes32 utxo, uint256 totalUtxoInsertions);

    function getTaxiTreeRoot() public view returns (bytes32) {
        return
            _currentRoot == bytes32(0)
                ? EIGHT_LEVEL_EMPTY_TREE_ROOT
                : _currentRoot;
    }

    function _addUtxos(
        bytes32[] memory utxos
    ) internal returns (bytes32 newRoot) {
        newRoot;

        for (uint256 i = 0; i < utxos.length; ) {
            newRoot = _addUtxoToTaxiTree(utxos[i]);

            unchecked {
                ++i;
            }
        }

        _updateTaxiTreeRoot(newRoot, utxos.length);
    }

    function _addUtxo(bytes32 utxo) internal returns (bytes32 newRoot) {
        newRoot = _addUtxoToTaxiTree(utxo);

        _updateTaxiTreeRoot(newRoot, 1);
    }

    function _addUtxoToTaxiTree(
        bytes32 utxo
    ) private returns (bytes32 newRoot) {
        uint256 _totalLeavesInsertions = totalLeavesInsertions;
        uint256 leafIndex;

        unchecked {
            leafIndex = _totalLeavesInsertions % MAX_LEAF_NUM;
            ++_totalLeavesInsertions;
        }

        newRoot = _insertLeaf(leafIndex, utxo);
        totalLeavesInsertions = _totalLeavesInsertions;

        emit TaxiUtxoAdded(utxo, _totalLeavesInsertions);
    }

    function _updateTaxiTreeRoot(
        bytes32 taxiTreeNewRoot,
        uint256 numLeaves
    ) private {
        _currentRoot = taxiTreeNewRoot;

        emit TaxiRootUpdated(taxiTreeNewRoot, numLeaves);
    }
}
