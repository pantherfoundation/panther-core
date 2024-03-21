// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./pantherForest/interfaces/ITreeRootUpdater.sol";
import "./pantherForest/interfaces/ITreeRootGetter.sol";

import "./pantherForest/merkleTrees/BinaryUpdatableTree.sol";
import "../../common/crypto/PoseidonHashers.sol";
import "../../common/ImmutableOwnable.sol";

import { ZNETWORK_STATIC_LEAF_INDEX } from "./pantherForest/Constants.sol";
import { SIX_LEVEL_EMPTY_TREE_ROOT } from "./pantherForest/zeroTrees/Constants.sol";

/**
 * @title ZNetworksRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

contract ZNetworksRegistry is
    ImmutableOwnable,
    BinaryUpdatableTree,
    ITreeRootGetter
{
    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;

    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    event ZNetworkTreeUpdated(bytes32 newRoot);

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

        // Trusted contract - no reentrancy guard needed
        PANTHER_STATIC_TREE.updateRoot(
            zNetworkTreeRoot,
            ZNETWORK_STATIC_LEAF_INDEX
        );

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
