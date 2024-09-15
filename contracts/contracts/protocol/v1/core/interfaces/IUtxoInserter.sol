// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IUtxoInserter {
    function addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint256 cachedForestRootIndex,
        bytes32 forestRoot,
        bytes32 staticRoot,
        uint96 reward
    ) external returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue);

    function addUtxosToBusQueueAndTaxiTree(
        bytes32[] memory utxos,
        uint8 numTaxiUtxos,
        uint256 cachedForestRootIndex,
        bytes32 forestRoot,
        bytes32 staticRoot,
        uint96 reward
    ) external returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue);
}
