// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";

import "../../diamond/utils/Ownable.sol";

/**
 * @title AppConfiguration
 * @notice Manages configuration stored in the Diamond's App storage, including
 * circuit IDs and block time offset.
 * @dev All of the Diamond's facets share access to the App storage. The getter methods
 * for reading the App storage are defined only in this facet, as each function can be
 * added to the Diamond only once.
 */
contract AppConfiguration is AppStorage, Ownable {
    /// @notice Emitted when the circuit ID is updated for a specific transaction type.
    /// @param txType The type of transaction being updated.
    /// @param newId The new circuit ID associated with the transaction type
    event CircuitIdUpdated(uint16 txType, uint160 newId);

    /// @notice Emitted when the maximum block time offset is updated.
    /// @param maxBlockTimeOffset The new maximum block time offset.
    event MaxBlockTimeOffsetUpdated(uint256 maxBlockTimeOffset);

    /**
     * @notice Updates the circuit ID for a given transaction type.
     * @param txType The type of transaction for which the circuit ID is being updated.
     * @param circuitId The new circuit ID to be set for the given transaction type.
     * @dev This function can only be called by the contract owner.
     * Transaction types can include 0x100 for zAccount activation or 0x106 for zSwap.
     */
    function updateCircuitId(
        uint16 txType,
        uint160 circuitId
    ) external onlyOwner {
        require(circuitId != 0, "Zero circuit id");

        circuitIds[txType] = circuitId;
        emit CircuitIdUpdated(txType, circuitId);
    }

    /**
     * @notice Updates the maximum block time offset.
     * @param _maxBlockTimeOffset The new maximum block time offset value to be set.
     * @dev  This function can only be called by the contract owner.
     * The difference between the createTime or spendTime provided by the user as a
     * public signal and the current block time must not exceed the maxBlockTimeOffset.
     * This check can be disabled by setting _maxBlockTimeOffset to 0.
     */
    function updateMaxBlockTimeOffset(
        uint32 _maxBlockTimeOffset
    ) external onlyOwner {
        require(
            _maxBlockTimeOffset <= 60 minutes,
            "Too high block time offset"
        );
        maxBlockTimeOffset = _maxBlockTimeOffset;

        emit MaxBlockTimeOffsetUpdated(_maxBlockTimeOffset);
    }

    /**
     * @notice Retrieves the circuit ID for a given transaction type.
     * @param txType The transaction type for which to fetch the circuit ID.
     * @return The circuit ID associated with the given pointer.
     */
    function getCircuitIds(uint16 txType) external view returns (uint160) {
        return circuitIds[txType];
    }

    /**
     * @notice Retrieves the current maximum block time offset.
     * @return The maximum block time offset.
     */
    function getMaxBlockTimeOffset() external view returns (uint32) {
        return maxBlockTimeOffset;
    }

    /**
     * @notice Checks if a given nullifier has already been spent.
     * @param nullifier The nullifier to check.
     * @return The block number at which the nullifier was spent, or 0 if
     * it has not been spent.
     */
    function getIsSpent(bytes32 nullifier) external view returns (uint256) {
        return isSpent[nullifier];
    }
}
