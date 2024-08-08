// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./interfaces/IPantherTaxiTree.sol";
import "./pantherForest/interfaces/ITreeRootGetter.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";

import "./pantherForest/taxiTree/TaxiTree.sol";
import { EIGHT_LEVEL_EMPTY_TREE_ROOT } from "./pantherForest/zeroTrees/Constants.sol";
import { TAXI_TREE_FOREST_LEAF_INDEX } from "./pantherForest/Constants.sol";

import "../../common/ImmutableOwnable.sol";

/**
 * @title PantherTaxiTree
 * @author Pantherprotocol Contributors
 * @dev It enables the direct insertion of an array of UTXOs into the TaxiTree.
 */
contract PantherTaxiTree is
    TaxiTree,
    ImmutableOwnable,
    ITreeRootGetter,
    IPantherTaxiTree
{
    address public immutable PANTHER_POOL;

    bytes32 private _currentRoot;

    event TaxiRootUpdated(bytes32 updatedRoot, uint256 numLeaves);
    event TaxiUtxoAdded(bytes32 utxo, uint256 totalUtxoInsertions);

    constructor(address pantherPool) ImmutableOwnable(pantherPool) {
        require(pantherPool != address(0), "Init");

        PANTHER_POOL = pantherPool;
    }

    function getRoot() external view returns (bytes32) {
        return
            _currentRoot == bytes32(0)
                ? EIGHT_LEVEL_EMPTY_TREE_ROOT
                : _currentRoot;
    }

    function addUtxos(bytes32[] calldata utxos) external onlyOwner {
        bytes32 newRoot;

        for (uint256 i = 0; i < utxos.length; ) {
            newRoot = _addUtxo(utxos[i]);

            unchecked {
                ++i;
            }
        }

        _updateTaxiAndForestRoots(newRoot, utxos.length);
    }

    function addUtxo(bytes32 utxo) external onlyOwner {
        bytes32 newRoot = _addUtxo(utxo);

        _updateTaxiAndForestRoots(newRoot, 1);
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

    function _updateTaxiAndForestRoots(
        bytes32 taxiTreeNewRoot,
        uint256 numLeaves
    ) private {
        // Synchronize the sate of `PantherForest` contract
        // Trusted contract - no reentrancy guard needed
        ITreeRootUpdater(PANTHER_POOL).updateRoot(
            taxiTreeNewRoot,
            TAXI_TREE_FOREST_LEAF_INDEX
        );

        _currentRoot = taxiTreeNewRoot;

        emit TaxiRootUpdated(taxiTreeNewRoot, numLeaves);
    }
}
