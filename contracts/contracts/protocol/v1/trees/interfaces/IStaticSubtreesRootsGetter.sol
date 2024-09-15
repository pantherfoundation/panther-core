// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IStaticSubtreesRootsGetter {
    function getBlacklistedZAccountsRoot() external view returns (bytes32);

    function getProvidersKeysRoot() external view returns (bytes32);

    function getZAssetsRoot() external view returns (bytes32);

    function getZNetworksRoot() external view returns (bytes32);

    function getZZonesRoot() external view returns (bytes32);
}
