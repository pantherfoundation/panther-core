// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/StaticTreeStorageGap.sol";

import "../interfaces/IStaticTreeRootUpdater.sol";
import "../interfaces/IStaticSubtreesRootsGetter.sol";
import "../utils/Constants.sol";

import "../../diamond/utils/Ownable.sol";
import "../../../../common/crypto/PoseidonHashers.sol";

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
contract StaticTree is
    AppStorage,
    StaticTreeStorageGap,
    Ownable,
    IStaticTreeRootUpdater
{
    uint256 private constant NUM_LEAFS = 5;

    address private immutable SELF;

    bytes32[NUM_LEAFS] public leafs;

    // mapping from leaf index to leaf owner
    mapping(uint8 => address) public leafControllers;

    event RootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot
    );

    constructor(address _self) {
        require(_self != address(0), "init: zero address");

        SELF = _self;
    }

    function getStaticRoot() external view returns (bytes32) {
        return staticRoot;
    }

    function initializeStaticTree() external onlyOwner {
        require(staticRoot == bytes32(0), "PF: Already initialized");

        leafs[ZASSET_STATIC_LEAF_INDEX] = IStaticSubtreesRootsGetter(SELF)
            .getZAssetsRoot();
        leafs[
            BLACKLISTED_ZACCOUNT_STATIC_LEAF_INDEX
        ] = IStaticSubtreesRootsGetter(SELF).getBlacklistedZAccountsRoot();
        leafs[ZNETWORK_STATIC_LEAF_INDEX] = IStaticSubtreesRootsGetter(SELF)
            .getZNetworksRoot();
        leafs[ZZONE_STATIC_LEAF_INDEX] = IStaticSubtreesRootsGetter(SELF)
            .getZZonesRoot();
        leafs[PROVIDERS_KEYS_STATIC_LEAF_INDEX] = IStaticSubtreesRootsGetter(
            SELF
        ).getProvidersKeysRoot();

        staticRoot = hash(leafs);
    }

    function updateStaticRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        require(leafIndex < NUM_LEAFS, "PF: INVALID_LEAF_IND");
        require(msg.sender == SELF, "unauthorized");

        leafs[leafIndex] = updatedLeaf;
        staticRoot = hash(leafs);

        emit RootUpdated(leafIndex, updatedLeaf, staticRoot);
    }

    function hash(bytes32[5] memory input) private pure returns (bytes32) {
        // We trust the caller provides all input values within the SNARK field
        return PoseidonHashers.poseidonT6(input);
    }
}
