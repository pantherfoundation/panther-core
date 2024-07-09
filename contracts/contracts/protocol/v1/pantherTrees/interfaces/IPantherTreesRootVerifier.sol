// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IPantherTreesRootVerifier {
    function verifyPantherTreesRoots(
        uint256 _cachedForestRootIndex,
        bytes32 _pantherForestRoot,
        bytes32 _pantherStaticRoot
    ) external view returns (bool);
}
