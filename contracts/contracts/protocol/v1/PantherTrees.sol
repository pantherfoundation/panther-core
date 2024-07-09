// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./pantherTrees/interfaces/IPantherTreesRootGetter.sol";
import "./pantherTrees/Constants.sol";

import "./pantherTrees/PantherForest.sol";
import "./pantherTrees/PantherStaticTree.sol";

import "./pantherTrees/PantherTaxiTree.sol";
import "./pantherTrees/PantherBusTree.sol";
import "./pantherTrees/PantherFerryTree.sol";

contract PantherTrees is
    PantherForest,
    PantherStaticTree,
    PantherTaxiTree,
    PantherBusTree,
    PantherFerryTree,
    IPantherTreesRootGetter
{
    bytes32[50] private _gap;

    event Initialized(bytes32 pantherForestRoot, bytes32 pantherStaticRoot);

    constructor(
        address _owner,
        address _pantherPool,
        address _pantherVerifier,
        address _feeMaster,
        address _zkpToken,
        PantherStaticTrees memory pantherStaticTrees
    )
        PantherStaticTree(pantherStaticTrees)
        PantherTaxiTree(_pantherPool)
        PantherBusTree(
            _owner,
            _pantherPool,
            _pantherVerifier,
            _feeMaster,
            _zkpToken
        )
    {}

    function getRoots() external view returns (bytes32, bytes32) {
        return (pantherStaticRoot, pantherForestRoot);
    }

    function verifyPantherTreesRoots(
        uint256 _cachedForestRootIndex,
        bytes32 _pantherForestRoot,
        bytes32 _pantherStaticRoot
    ) external view returns (bool) {
        return
            isCachedRoot(_pantherForestRoot, _cachedForestRootIndex) &&
            _pantherStaticRoot == pantherStaticRoot;
    }

    function initialize() external onlyOwner {
        bytes32 taxiTreeRoot = getTaxiTreeRoot();
        bytes32 busTreeRoot = getBusTreeRoot();
        bytes32 ferryTreeRoot = getFerryTreeRoot();

        bytes32 _pantherForestRoot = _initializeForest(
            taxiTreeRoot,
            busTreeRoot,
            ferryTreeRoot
        );
        bytes32 _pantherStaticRoot = _initializeStaticTree();

        // TODO initializeBusTree

        emit Initialized(_pantherForestRoot, _pantherStaticRoot);
    }

    // function addUtxos(
    //     bytes32[] memory utxos,
    //     uint96 reward,
    //     bool isTaxiApplicable
    // ) external returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue) {
    //     require(msg.sender == PANTHER_POOL, "");
    //     require(utxos.length != 0, ERR_EMPTY_UTXOS_ARRAY);

    //     (firstUtxoQueueId, firstUtxoIndexInQueue) = _addUtxosToBusQueue(
    //         utxos,
    //         reward
    //     );

    //     if (isTaxiApplicable) {}
    // }

    function _updateForestRoot(
        bytes32 updatedLeaf,
        uint256 leafIndex
    ) internal override(PantherBusTree, PantherTaxiTree, PantherFerryTree) {
        PantherForest.updateForestRoot(updatedLeaf, leafIndex);
    }
}
