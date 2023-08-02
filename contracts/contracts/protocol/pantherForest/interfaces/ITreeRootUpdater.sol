// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

interface ITreeRootUpdater {
    event RootUpdated(
        uint8 indexed leafIndex,
        bytes32 updatedLeaf,
        bytes32 updatedRoot
    );

    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external;
}
