// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./interfaces/ITreeRootGetter.sol";

import "./Constants.sol";
import "./Types.sol";
import "../../../common/crypto/PoseidonHashers.sol";

abstract contract PantherStaticTree {
    bytes32[50] private _startGap;

    uint256 private constant NUM_STATIC_TREE_LEAFS = 5;

    address public immutable ZASSETS_TREE_CONTROLLER;
    address public immutable ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER;
    address public immutable ZNETWORKS_TREE_CONTROLLER;
    address public immutable ZZONES_TREE_CONTROLLER;
    address public immutable PROVIDERS_KEYS_TREE_CONTROLLER;

    bytes32[NUM_STATIC_TREE_LEAFS] public staticTreeleafs;
    // mapping from leaf index to leaf owner
    mapping(uint8 => address) public staticTreeLeafControllers;

    bytes32 public pantherStaticRoot;

    bytes32[50] private _endGap;

    event StaticRootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot
    );

    constructor(PantherStaticTrees memory pantherStaticTrees) {
        ZASSETS_TREE_CONTROLLER = pantherStaticTrees.zAssetsTreeController;
        ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER = pantherStaticTrees
            .zAccountsBlacklistedTreeController;
        ZNETWORKS_TREE_CONTROLLER = pantherStaticTrees.zNetworksTreeController;
        ZZONES_TREE_CONTROLLER = pantherStaticTrees.zZnonesTreeController;
        PROVIDERS_KEYS_TREE_CONTROLLER = pantherStaticTrees
            .providersKeysTreeController;
    }

    function _initializeStaticTree()
        internal
        returns (bytes32 _pantherStaticRoot)
    {
        require(pantherStaticRoot == bytes32(0), "PF: Already initialized");

        for (uint8 i; i < NUM_STATIC_TREE_LEAFS; ) {
            staticTreeleafs[i] = ITreeRootGetter(
                _getStaticTreeLeafController(i)
            ).getRoot();

            unchecked {
                ++i;
            }
        }

        _pantherStaticRoot = PoseidonHashers.poseidonT6(staticTreeleafs);

        pantherStaticRoot = _pantherStaticRoot;
    }

    function updateStaticRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        require(
            msg.sender == _getStaticTreeLeafController(leafIndex),
            "unauthorized"
        );

        staticTreeleafs[leafIndex] = updatedLeaf;
        // PoseidonHashers validates input values to be within the SNARK field
        pantherStaticRoot = PoseidonHashers.poseidonT6(staticTreeleafs);

        emit StaticRootUpdated(leafIndex, updatedLeaf, pantherStaticRoot);
    }

    function _getStaticTreeLeafController(
        uint256 leafIndex
    ) internal view returns (address leafController) {
        require(leafIndex < NUM_STATIC_TREE_LEAFS, "PF: INVALID_LEAF_IND");
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
}
