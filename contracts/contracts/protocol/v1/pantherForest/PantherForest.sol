// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./interfaces/ITreeRootGetter.sol";
import "./interfaces/ITreeRootUpdater.sol";

import "./cachedRoots/CachedRoots.sol";

import "../../../common/ImmutableOwnable.sol";
import "../../../common/crypto/PoseidonHashers.sol";
import "./Constants.sol";
import "./Types.sol";

/**
 * @title PantherForest
 * @notice It stores and updates leafs and the root of the Panther Forest Tree.
 * @dev "Panther Forest Tree" is a merkle tree with a single level (leafs) under
 * the root. It has 3 leafs, which are roots of 3 other merkle trees -
 * the "Taxi Tree", the "Bus Tree" and, the "Ferry Tree".
 * (essentially, these 3 trees are subtree of the Panther Forest tree):
 *
 *      Forest Root
 *            |
 *     +------+------+
 *     |      |      |
 *     0      1      2
 *   Taxi    Bus    Ferry
 *   Tree    Tree   Tree
 *   root    root   root
 *
 * Every of 3 trees are controlled by "tree" smart contracts. A "tree" contract
 * must call this contract to update the value of the leaf and the root of the
 * Forest Tree every time the "controlled" tree is updated.
 * It supports a "history" of recent roots, so that users may refer not only to
 * the latest root, but on former roots cached in the history.
 */
abstract contract PantherForest is
    CachedRoots,
    ImmutableOwnable,
    ITreeRootGetter,
    ITreeRootUpdater
{
    bytes32[10] private _startGap;

    uint256 private constant NUM_LEAFS = 3;

    address public immutable TAXI_TREE_CONTROLLER;
    address public immutable BUS_TREE_CONTROLLER;
    address public immutable FERRY_TREE_CONTROLLER;

    bytes32 private _forestRoot;

    bytes32[NUM_LEAFS] public leafs;

    event RootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot,
        uint256 cacheIndex
    );

    bytes32[11] private _endGap;

    constructor(
        address _owner,
        ForestTrees memory forestTrees
    ) ImmutableOwnable(_owner) {
        require(
            forestTrees.taxiTree != address(0) &&
                forestTrees.busTree != address(0) &&
                forestTrees.ferryTree != address(0),
            "init: zero address"
        );

        TAXI_TREE_CONTROLLER = forestTrees.taxiTree;
        BUS_TREE_CONTROLLER = forestTrees.busTree;
        FERRY_TREE_CONTROLLER = forestTrees.ferryTree;
    }

    function initialize() external onlyOwner {
        require(_forestRoot == bytes32(0), "PF: Already initialized");

        for (uint8 i; i < NUM_LEAFS; ) {
            leafs[i] = ITreeRootGetter(_getLeafController(i)).getRoot();
            unchecked {
                ++i;
            }
        }

        _forestRoot = hash(leafs);
        cacheNewRoot(_forestRoot);
    }

    function getRoot() external view returns (bytes32) {
        return _forestRoot;
    }

    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        require(msg.sender == _getLeafController(leafIndex), "unauthorized");

        leafs[leafIndex] = updatedLeaf;
        bytes32 forestRoot = hash(leafs);
        uint256 cacheIndex = cacheNewRoot(forestRoot);

        _forestRoot = forestRoot;
        emit RootUpdated(leafIndex, updatedLeaf, forestRoot, cacheIndex);
    }

    function _getLeafController(
        uint256 leafIndex
    ) internal view returns (address leafController) {
        require(leafIndex < NUM_LEAFS, "PF: INVALID_LEAF_IND");
        if (leafIndex == TAXI_TREE_FOREST_LEAF_INDEX)
            leafController = TAXI_TREE_CONTROLLER;

        if (leafIndex == BUS_TREE_FOREST_LEAF_INDEX)
            leafController = BUS_TREE_CONTROLLER;

        if (leafIndex == FERRY_TREE_FOREST_LEAF_INDEX)
            leafController = FERRY_TREE_CONTROLLER;
    }

    function hash(
        bytes32[NUM_LEAFS] memory _leafs
    ) internal pure returns (bytes32) {
        return PoseidonHashers.poseidonT4(_leafs);
    }
}
