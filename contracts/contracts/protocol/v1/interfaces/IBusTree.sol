// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IBusTree {
    function addUtxosToBusQueue(
        bytes32[] calldata utxo,
        uint96 rewards
    ) external returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue);

    function addUtxoToBusQueue(
        bytes32 utxo
    ) external returns (uint32 queueId, uint8 indexInQueue);
}
