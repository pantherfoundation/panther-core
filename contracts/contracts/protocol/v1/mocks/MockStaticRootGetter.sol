// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../trees/interfaces/IStaticSubtreesRootsGetter.sol";
import { SIXTEEN_LEVEL_EMPTY_TREE_ROOT, SIX_LEVEL_EMPTY_TREE_ROOT } from "../trees/utils/zeroTrees/Constants.sol";

contract MockStaticRootGetter is IStaticSubtreesRootsGetter {
    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    function getRoot() internal view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function zeroRoot() internal pure returns (bytes32) {
        return SIXTEEN_LEVEL_EMPTY_TREE_ROOT;
    }

    function getBlacklistedZAccountsRoot() external view returns (bytes32) {
        return getRoot();
    }

    function getProvidersKeysRoot() external view returns (bytes32) {
        return SIX_LEVEL_EMPTY_TREE_ROOT;
    }

    function getZAssetsRoot() external view returns (bytes32) {
        return getRoot();
    }

    function getZNetworksRoot() external view returns (bytes32) {
        return getRoot();
    }

    function getZZonesRoot() external view returns (bytes32) {
        return getRoot();
    }
}
