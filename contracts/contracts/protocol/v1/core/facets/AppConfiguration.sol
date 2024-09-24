// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";

import "../../diamond/utils/Ownable.sol";

contract AppConfiguration is AppStorage, Ownable {
    event CircuitIdUpdated(uint16 txType, uint160 newId);
    event MaxBlockTimeOffsetUpdated(uint256 maxBlockTimeOffset);

    function updateCircuitId(
        uint16 txType,
        uint160 circuitId
    ) external onlyOwner {
        circuitIds[txType] = circuitId;
        emit CircuitIdUpdated(txType, circuitId);
    }

    function updateMaxBlockTimeOffset(
        uint32 _maxBlockTimeOffset
    ) external onlyOwner {
        maxBlockTimeOffset = _maxBlockTimeOffset;

        emit MaxBlockTimeOffsetUpdated(_maxBlockTimeOffset);
    }

    function getCircuitIds(uint16 pointer) external view returns (uint160) {
        return circuitIds[pointer];
    }

    function getMaxBlockTimeOffset() external view returns (uint32) {
        return maxBlockTimeOffset;
    }

    function getIsSpent(bytes32 nullifier) external view returns (uint256) {
        return isSpent[nullifier];
    }
}
