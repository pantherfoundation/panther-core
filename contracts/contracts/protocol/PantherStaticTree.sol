// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { PoseidonT6 } from "./crypto/Poseidon.sol";
import "./pantherForest/interfaces/ITreeRootGetter.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";
import "../common/ImmutableOwnable.sol";
import { STATIC_TREE_FOREST_LEAF_INDEX } from "./pantherForest/Constant.sol";

// (updating the state of the PantherForest contract on a network).
// It's a one-level quin tree that holds the roots of the following trees:
// - ZAssetsTree,
// - ZZonesTree,
// - ProvidersKeysList,
// - ZAccountsBlacklist,
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

    // solhint-disable var-name-mixedcase

    uint256 private constant NUM_LEAFS = 5;

    address public immutable PANTHER_FOREST;

    address public immutable ZASSETS_TREE_CONTROLLER;
    address public immutable ZZONES_TREE_CONTROLLER;
    address public immutable PROVIDERS_KEYS_TREE_CONTROLLER;
    address public immutable ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER;
    address public immutable ZNETWORKS_TREE_CONTROLLER;

    // solhint-enable var-name-mixedcase

    bytes32 private _staticTreeRoot;
    bytes32[NUM_LEAFS] public leafs;

    // mapping from leaf index to leaf owner
    mapping(uint8 => address) public leafControllers;

    constructor(
        address _owner,
        address _pantherForest,
        address _zAssetsTreeController,
        address _zZnonesTreeController,
        address _providersKeysTreeController,
        address _zAccountsBlacklistedTreeController,
        address _zNetworksTreeController
    ) ImmutableOwnable(_owner) {
        require(
            _zAssetsTreeController != address(0) &&
                _zZnonesTreeController != address(0) &&
                _providersKeysTreeController != address(0) &&
                _zAccountsBlacklistedTreeController != address(0) &&
                _zNetworksTreeController != address(0),
            "init: zero address"
        );

        PANTHER_FOREST = _pantherForest;
        ZASSETS_TREE_CONTROLLER = _zAssetsTreeController;
        ZZONES_TREE_CONTROLLER = _zZnonesTreeController;
        PROVIDERS_KEYS_TREE_CONTROLLER = _providersKeysTreeController;
        ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER = _zAccountsBlacklistedTreeController;
        ZNETWORKS_TREE_CONTROLLER = _zNetworksTreeController;
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

        emit RootUpdated(uint8(leafIndex), updatedLeaf, _staticTreeRoot);
    }

    function _getLeafController(uint256 leafIndex)
        internal
        view
        returns (address)
    {
        require(leafIndex < NUM_LEAFS, "PF: INVALID_LEAF_IND");
        return
            [
                ZASSETS_TREE_CONTROLLER,
                ZZONES_TREE_CONTROLLER,
                PROVIDERS_KEYS_TREE_CONTROLLER,
                ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER,
                ZNETWORKS_TREE_CONTROLLER
            ][leafIndex];
    }

    function hash(bytes32[5] memory input) private pure returns (bytes32) {
        // We trust the caller provides all input values within the SNARK field
        return PoseidonT6.poseidon(input);
    }
}
