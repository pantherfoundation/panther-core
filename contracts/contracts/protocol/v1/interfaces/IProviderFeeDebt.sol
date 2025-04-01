// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IProviderFeeDebt {
    /**
     * @notice Retrieves the debt amount owed by a specific provider for a given token.
     * @dev This function serves as a getter for the `debts` mapping, allowing external contracts
     *      and users to query the debt amount of providers for specific ERC20 tokens.
     * @return The total debt amount (`uint256`) that the specified `provider` owes in the specified `token`.
     */
    function debts(
        address provider,
        address token
    ) external view returns (uint256);
}
