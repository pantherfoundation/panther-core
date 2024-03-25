// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./pantherForest/interfaces/ITreeRootUpdater.sol";
import "./pantherForest/interfaces/ITreeRootGetter.sol";
import "./interfaces/IPantherTaxiTree.sol";

import "./pantherForest/taxiTree/TaxiTree.sol";
import { TAXI_TREE_FOREST_LEAF_INDEX } from "./pantherForest/Constants.sol";
import { TWO_LEVEL_EMPTY_TREE_ROOT } from "./pantherForest/zeroTrees/Constants.sol";

import "../../common/ImmutableOwnable.sol";

/**
 * @title PantherTaxiTree
 * @author Pantherprotocol Contributors
 * @dev It enables the direct insertion of UTXOs with a maximum capacity of 4 into the
 * Panther Forest. With each insertion, the old leaves are rewritten, and a new root is
 * generated. This root then serves as a leaf within the PantherForest Merkle tree.
 */
contract PantherTaxiTree is TaxiTree, ITreeRootGetter, IPantherTaxiTree {
    address public immutable PANTHER_POOL;

    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    event RootUpdated(uint256 numLeaves, bytes32 updatedRoot);

    constructor(address pantherPool) {
        require(pantherPool != address(0), "Init");

        PANTHER_POOL = pantherPool;
    }

    modifier onlyPantherPool() {
        require(msg.sender == PANTHER_POOL, "Unauthorized");
        _;
    }

    function getRoot() external view returns (bytes32) {
        return
            _currentRoot == bytes32(0)
                ? TWO_LEVEL_EMPTY_TREE_ROOT
                : _currentRoot;
    }

    function addUtxo(bytes32 utxo) external onlyPantherPool {
        uint8 numLeaves = 1;

        bytes32 taxiTreeNewRoot = _insert(utxo);

        _updateTaxiAndStaticTreeRoots(taxiTreeNewRoot, numLeaves);

        emit RootUpdated(numLeaves, taxiTreeNewRoot);
    }

    function addUtxos(
        bytes32 utxo0,
        bytes32 utxo1,
        bytes32 utxo2
    ) external onlyPantherPool {
        uint8 numLeaves = 3;
        bytes32 taxiTreeNewRoot = _insert(utxo0, utxo1, utxo2);

        _updateTaxiAndStaticTreeRoots(taxiTreeNewRoot, numLeaves);
    }

    function _updateTaxiAndStaticTreeRoots(
        bytes32 taxiTreeNewRoot,
        uint8 numLeaves
    ) private {
        // Synchronize the sate of `PantherForest` contract
        // Trusted contract - no reentrancy guard needed
        ITreeRootUpdater(PANTHER_POOL).updateRoot(
            taxiTreeNewRoot,
            TAXI_TREE_FOREST_LEAF_INDEX
        );

        _currentRoot = taxiTreeNewRoot;

        emit RootUpdated(numLeaves, taxiTreeNewRoot);
    }
}
