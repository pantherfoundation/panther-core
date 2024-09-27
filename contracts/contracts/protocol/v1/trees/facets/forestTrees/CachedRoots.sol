// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "./cachedRoots/RingBufferRootCache.sol";
import { TAXI_TREE_FOREST_LEAF_INDEX, BUS_TREE_FOREST_LEAF_INDEX, FERRY_TREE_FOREST_LEAF_INDEX } from "../../utils/Constants.sol";

import "../../../../../common/crypto/PoseidonHashers.sol";

// import "../../../common/ImmutableOwnable.sol";

// import "./Constants.sol";
// import "./Types.sol";

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
abstract contract CachedRoots is RingBufferRootCache {
    uint256 private constant NUM_FOREST_LEAFS = 3;
    bytes32[NUM_FOREST_LEAFS] public forestLeafs;

    event ForestRootUpdated(
        uint256 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot,
        uint256 cacheIndex
    );

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
