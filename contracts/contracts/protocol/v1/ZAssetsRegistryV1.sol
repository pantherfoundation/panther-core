// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./pantherTrees/interfaces/ITreeRootUpdater.sol";
import "./pantherTrees/interfaces/ITreeRootGetter.sol";

import "./pantherTrees/merkleTrees/BinaryUpdatableTree.sol";
import "../../common/crypto/PoseidonHashers.sol";
import "../../common/ImmutableOwnable.sol";

import { ZASSET_STATIC_LEAF_INDEX } from "./pantherTrees/Constants.sol";
import { SIXTEEN_LEVEL_EMPTY_TREE_ROOT } from "./pantherTrees/zeroTrees/Constants.sol";

/**
 * @title ZAssetsRegistryV1
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

contract ZAssetsRegistryV1 is
    ImmutableOwnable,
    BinaryUpdatableTree,
    ITreeRootGetter
{
    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;

    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    event ZAssetTreeUpdated(bytes32 newRoot);

    constructor(
        address _owner,
        address pantherStaticTree
    ) ImmutableOwnable(_owner) {
        require(pantherStaticTree != address(0), "Init");

        PANTHER_STATIC_TREE = ITreeRootUpdater(pantherStaticTree);
    }

    function getRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function addZAsset(
        bytes32 curRoot,
        bytes32 curLeaf,
        bytes32 newLeaf,
        uint256 leafIndex,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        bytes32 zAssetsTreeRoot = update(
            curRoot,
            curLeaf,
            newLeaf,
            leafIndex,
            proofSiblings
        );

        // Trusted contract - no reentrancy guard needed
        PANTHER_STATIC_TREE.updateRoot(
            zAssetsTreeRoot,
            ZASSET_STATIC_LEAF_INDEX
        );

        _currentRoot = zAssetsTreeRoot;

        emit ZAssetTreeUpdated(zAssetsTreeRoot);
    }

    //@dev returns the root of tree with depth 16 where each leaf is ZERO_VALUE
    function zeroRoot() internal pure override returns (bytes32) {
        return SIXTEEN_LEVEL_EMPTY_TREE_ROOT;
    }

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }
}
