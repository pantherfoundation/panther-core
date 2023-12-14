// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./pantherForest/interfaces/ITreeRootGetter.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";
import "./pantherForest/Constants.sol";

import "../common/ImmutableOwnable.sol";
import "./crypto/PoseidonHashers.sol";

// TODO: write PantherStaticTree 'title' and 'notice' (description) similarly to the contracts have
// (updating the state of the PantherForest contract on a network).
// It's a one-level quin tree that holds the roots of the following trees:
// - ZAssetsTree,
// - ZZonesTree,
// - ProvidersKeys tree,
// - ZAccountsBlacklist tree,
// - ZNetworksTree
//
// It's supposed to run on the mainnet only.
// Bridges keepers are expected to propagate its root to other networks
contract PantherStaticTree is
    ImmutableOwnable,
    ITreeRootGetter,
    ITreeRootUpdater
{
    bytes32[50] private _gap;

    uint256 private constant NUM_LEAFS = 5;

    address public immutable PANTHER_FOREST;

    address public immutable ZASSETS_TREE_CONTROLLER;
    address public immutable ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER;
    address public immutable ZNETWORKS_TREE_CONTROLLER;
    address public immutable ZZONES_TREE_CONTROLLER;
    address public immutable PROVIDERS_KEYS_TREE_CONTROLLER;

    bytes32 private _staticTreeRoot;
    bytes32[NUM_LEAFS] public leafs;

    // mapping from leaf index to leaf owner
    mapping(uint8 => address) public leafControllers;

    event RootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot
    );

    constructor(
        address _owner,
        address _pantherForest,
        address _zAssetsTreeController,
        address _zAccountsBlacklistedTreeController,
        address _zNetworksTreeController,
        address _zZnonesTreeController,
        address _providersKeysTreeController
    ) ImmutableOwnable(_owner) {
        require(
            _zAssetsTreeController != address(0) &&
                _zAccountsBlacklistedTreeController != address(0) &&
                _zNetworksTreeController != address(0) &&
                _zZnonesTreeController != address(0) &&
                _providersKeysTreeController != address(0),
            "init: zero address"
        );

        PANTHER_FOREST = _pantherForest;

        ZASSETS_TREE_CONTROLLER = _zAssetsTreeController;
        ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER = _zAccountsBlacklistedTreeController;
        ZNETWORKS_TREE_CONTROLLER = _zNetworksTreeController;
        ZZONES_TREE_CONTROLLER = _zZnonesTreeController;
        PROVIDERS_KEYS_TREE_CONTROLLER = _providersKeysTreeController;
    }

    function initialize() external onlyOwner {
        require(_staticTreeRoot == bytes32(0), "PF: Already initialized");

        for (uint8 i; i < NUM_LEAFS; ) {
            leafs[i] = ITreeRootGetter(_getLeafController(i)).getRoot();

            unchecked {
                ++i;
            }
        }

        _staticTreeRoot = hash(leafs);
    }

    // TODO: to be removed in production
    function setDebugRoot() external onlyOwner {
        for (uint8 i; i < NUM_LEAFS; ) {
            leafs[i] = ITreeRootGetter(_getLeafController(i)).getRoot();

            unchecked {
                ++i;
            }
        }

        _staticTreeRoot = hash(leafs);

        ITreeRootUpdater(PANTHER_FOREST).updateRoot(
            _staticTreeRoot,
            STATIC_TREE_FOREST_LEAF_INDEX
        );
    }

    function getRoot() external view returns (bytes32) {
        return _staticTreeRoot;
    }

    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        require(msg.sender == _getLeafController(leafIndex), "unauthorized");

        leafs[leafIndex] = updatedLeaf;
        _staticTreeRoot = hash(leafs);

        ITreeRootUpdater(PANTHER_FOREST).updateRoot(
            _staticTreeRoot,
            STATIC_TREE_FOREST_LEAF_INDEX
        );

        emit RootUpdated(leafIndex, updatedLeaf, _staticTreeRoot);
    }

    function _getLeafController(
        uint256 leafIndex
    ) internal view returns (address leafController) {
        require(leafIndex < NUM_LEAFS, "PF: INVALID_LEAF_IND");
        if (leafIndex == ZASSET_STATIC_LEAF_INDEX)
            leafController = ZASSETS_TREE_CONTROLLER;

        if (leafIndex == ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX)
            leafController = ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER;

        if (leafIndex == ZNETWORK_STATIC_LEAF_INDEX)
            leafController = ZNETWORKS_TREE_CONTROLLER;

        if (leafIndex == ZZONE_STATIC_LEAF_INDEX)
            leafController = ZZONES_TREE_CONTROLLER;

        if (leafIndex == PROVIDERS_KEYS_STATIC_LEAF_INDEX)
            leafController = PROVIDERS_KEYS_TREE_CONTROLLER;
    }

    function hash(bytes32[5] memory input) private pure returns (bytes32) {
        // We trust the caller provides all input values within the SNARK field
        return PoseidonHashers.poseidonT6(input);
    }
}
