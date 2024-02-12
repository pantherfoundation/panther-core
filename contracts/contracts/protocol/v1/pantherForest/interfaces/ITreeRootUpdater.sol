// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface ITreeRootUpdater {
    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external;
}
