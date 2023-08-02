// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

interface ITreeRootGetter {
    function getRoot() external view returns (bytes32);
}
