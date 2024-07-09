// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IPantherTreesRootGetter {
    function getRoots()
        external
        view
        returns (bytes32 _pantherStaticRoot, bytes32 _pantherForestRoot);
}
