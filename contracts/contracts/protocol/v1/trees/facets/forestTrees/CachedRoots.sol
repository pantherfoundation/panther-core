// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "./cachedRoots/RingBufferRootCache.sol";
import { TAXI_TREE_FOREST_LEAF_INDEX, BUS_TREE_FOREST_LEAF_INDEX, FERRY_TREE_FOREST_LEAF_INDEX } from "../../utils/Constants.sol";

import "../../../../../common/crypto/PoseidonHashers.sol";

/**
 * @title CachedRoots
 * @notice This contract manages the leaves and root of the Panther Forest Tree, enabling efficient updates and caching of roots.
 */
abstract contract CachedRoots is RingBufferRootCache {
    uint256 private constant NUM_FOREST_LEAFS = 3;
    bytes32[NUM_FOREST_LEAFS] public forestLeafs;

    event ForestRootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot,
        uint256 cacheIndex
    );

    /**
     * @notice Initializes the cache for the forest root with the provided roots from the subtree trees.
     * @param taxiTreeRoot The root of the Taxi Tree.
     * @param busTreeRoot The root of the Bus Tree.
     * @param ferryTreeRoot The root of the Ferry Tree.
     * @return _forestRoot The newly computed forest root after initialization.
     * @dev This function should be called to set up the forest root when initializing the contract.
     */

    function _initCacheForestRoot(
        bytes32 taxiTreeRoot,
        bytes32 busTreeRoot,
        bytes32 ferryTreeRoot
    ) internal returns (bytes32 _forestRoot) {
        forestLeafs[TAXI_TREE_FOREST_LEAF_INDEX] = taxiTreeRoot;
        forestLeafs[BUS_TREE_FOREST_LEAF_INDEX] = busTreeRoot;
        forestLeafs[FERRY_TREE_FOREST_LEAF_INDEX] = ferryTreeRoot;

        _forestRoot = PoseidonHashers.poseidonT4(forestLeafs);
        cacheNewRoot(_forestRoot);
    }

    /**
     * @notice Caches a new forest root and updates the specified leaf.
     * @param updatedLeaf The new value for the leaf being updated.
     * @param leafIndex The index of the leaf being updated; must be less than the total number of leaves.
     * @return _forestRoot The newly computed forest root after the update.
     * @dev Emits a ForestRootUpdated event after updating the root.
     * Reverts if the leafIndex is invalid.
     */
    function _cacheNewForestRoot(
        bytes32 updatedLeaf,
        uint256 leafIndex
    ) internal returns (bytes32 _forestRoot) {
        forestLeafs[leafIndex] = updatedLeaf;

        _forestRoot = PoseidonHashers.poseidonT4(forestLeafs);
        uint256 cacheIndex = cacheNewRoot(_forestRoot);

        emit ForestRootUpdated(leafIndex, updatedLeaf, _forestRoot, cacheIndex);
    }
}
