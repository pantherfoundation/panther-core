// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZNetworksRegistryStorageGap.sol";

import "./staticTrees/StaticRootUpdater.sol";

import "../../diamond/utils/Ownable.sol";
import "../utils/merkleTrees/BinaryUpdatableTree.sol";

import { ZNETWORK_STATIC_LEAF_INDEX } from "../utils/Constants.sol";
import { SIX_LEVEL_EMPTY_TREE_ROOT } from "../utils/zeroTrees/Constants.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

/**
 * @title ZNetworksRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

contract ZNetworksRegistry is
    AppStorage,
    ZNetworksRegistryStorageGap,
    StaticRootUpdater,
    Ownable,
    BinaryUpdatableTree
{
    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    event ZNetworkTreeUpdated(bytes32 newRoot);

    constructor(address self) StaticRootUpdater(self) {}

    function getZNetworksRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function addNetwork(
        bytes32 curRoot,
        bytes32 curLeaf,
        bytes32 newLeaf,
        uint256 leafIndex,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        bytes32 zNetworkTreeRoot = update(
            curRoot,
            curLeaf,
            newLeaf,
            leafIndex,
            proofSiblings
        );

        _updateStaticRoot(zNetworkTreeRoot, ZNETWORK_STATIC_LEAF_INDEX);

        _currentRoot = zNetworkTreeRoot;

        emit ZNetworkTreeUpdated(zNetworkTreeRoot);
    }

    //@dev returns the root of tree with depth 16 where each leaf is ZERO_VALUE
    function zeroRoot() internal pure override returns (bytes32) {
        return SIX_LEVEL_EMPTY_TREE_ROOT;
    }

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }
}
