// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/StaticTreeStorageGap.sol";

import "../interfaces/IStaticTreeRootUpdater.sol";
import "../interfaces/IStaticSubtreesRootsGetter.sol";
import "../utils/Constants.sol";

import "../../diamond/utils/Ownable.sol";
import "../../../../common/crypto/PoseidonHashers.sol";

/**
 * @title StaticTree
 * @notice This contract implements a one-level tree that holds the roots of multiple static sub trees.
 *
 *                        Static Root
 *                             |
 *     +----------+------------+-----------+--------------+
 *     |          |            |           |              |
 *     0          1            2           3              4
 *  ZAssets   Blacklisted   ZNetworks    ZZones      ProvidersKeys
 *   Tree      Accounts       Tree        Tree          Tree
 *   Root        Root         Root        Root          Root
 *
 * @dev The StaticTree is intended for deployment on the mainnet only. It is responsible for maintaining
 * and updating the static root. Bridges keepers are expected to propagate the root to other networks.
 * The contract owner can initialize the tree and update its roots.
 */
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

    event StaticRootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot
    );

    constructor(address _self) {
        require(_self != address(0), "init: zero address");

        SELF = _self;
    }

    /**
     * @notice Retrieves the current static root of the tree.
     * @return The static root as a bytes32 value.
     */
    function getStaticRoot() external view returns (bytes32) {
        return staticRoot;
    }

    /**
     * @notice Initializes the static tree with the roots from the respective subtrees.
     * @dev This function can only be called by the owner. It must be called before the static tree can be used.
     * Reverts if the static root has already been initialized.
     */
    function initializeStaticTree() external onlyOwner {
        require(staticRoot == bytes32(0), "ST: Already initialized");

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

    /**
     * @notice Updates the static root with a new leaf value.
     * @param updatedLeaf The new leaf value to be set.
     * @param leafIndex The index of the leaf to be updated; must be less than the total number of leaves.
     * @dev This function can only be called by the contract itself. It emits a RootUpdated event after
     * updating the root.
     * Reverts if the leafIndex is invalid or if the caller is unauthorized.
     */
    function updateStaticRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        require(staticRoot != bytes32(0), "ST: not initialized");

        require(leafIndex < NUM_LEAFS, "ST: INVALID_LEAF_IND");
        require(msg.sender == SELF, "unauthorized");

        leafs[leafIndex] = updatedLeaf;
        staticRoot = hash(leafs);

        emit StaticRootUpdated(leafIndex, updatedLeaf, staticRoot);
    }

    /**
     * @dev Computes the hash of the provided leaves using the Poseidon hashing function.
     * @param input An array of leaf values to be hashed.
     * @return The computed hash as a bytes32 value.
     * @dev This function ensures that all input values are within the SNARK field.
     */
    function hash(bytes32[5] memory input) private pure returns (bytes32) {
        // We trust the caller provides all input values within the SNARK field
        return PoseidonHashers.poseidonT6(input);
    }
}
