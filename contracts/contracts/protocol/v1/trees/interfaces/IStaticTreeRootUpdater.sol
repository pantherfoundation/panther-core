// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IStaticTreeRootUpdater {
    function updateStaticRoot(bytes32 updatedLeaf, uint256 leafIndex) external;
}
