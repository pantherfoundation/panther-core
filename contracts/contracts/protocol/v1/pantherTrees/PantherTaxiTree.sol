// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import ".//taxiTree/TaxiTree.sol";
import { EIGHT_LEVEL_EMPTY_TREE_ROOT } from "./zeroTrees/Constants.sol";

/**
 * @title PantherTaxiTree
 * @author Pantherprotocol Contributors
 * @dev It enables the direct insertion of an array of UTXOs into the TaxiTree.
 */
abstract contract PantherTaxiTree is TaxiTree {
    bytes32 private _currentRoot;

    event TaxiRootUpdated(bytes32 updatedRoot, uint256 numLeaves);
    event TaxiUtxoAdded(bytes32 utxo, uint256 totalUtxoInsertions);

    function getTaxiTreeRoot() public view returns (bytes32) {
        return
            _currentRoot == bytes32(0)
                ? EIGHT_LEVEL_EMPTY_TREE_ROOT
                : _currentRoot;
    }

    function addUtxos(bytes32[] calldata utxos) external {
        bytes32 newRoot;

        for (uint256 i = 0; i < utxos.length; ) {
            newRoot = _addUtxo(utxos[i]);

            unchecked {
                ++i;
            }
        }

        _currentRoot = newRoot;
    }

    function addUtxo(bytes32 utxo) external {
        _currentRoot = _addUtxo(utxo);

        // _updateTaxiAndForestRoots(newRoot, 1);
    }

    function _addUtxo(bytes32 utxo) private returns (bytes32 newRoot) {
        uint256 _totalLeavesInsertions = totalLeavesInsertions;
        uint256 leafIndex;

        unchecked {
            leafIndex = _totalLeavesInsertions % MAX_LEAF_NUM;
            totalLeavesInsertions = _totalLeavesInsertions + 1;
        }

        newRoot = _insertLeaf(leafIndex, utxo);

        emit TaxiUtxoAdded(utxo, _totalLeavesInsertions);
    }

    // function _updateTaxiRootAndEmitEvent(
    //     bytes32 taxiTreeNewRoot,
    //     uint256 numLeaves
    // ) private {
    //     _currentRoot = taxiTreeNewRoot;

    //     emit TaxiRootUpdated(taxiTreeNewRoot, numLeaves);
    // }
}
