// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

library TransactionOptions {
    function cachedForestRootIndex(
        uint32 transactionOptions
    ) internal pure returns (uint256) {
        // The 8 LSB contains the cachedForestRootIndex
        // returning the total 16 bits to reduce attack surface.

        return transactionOptions & 0xFFFF;
    }

    function isTaxiApplicable(
        uint32 transactionOptions
    ) internal pure returns (bool) {
        // The 1 MSB contains the TaxiEnabler

        return (transactionOptions >> 16) == 1;
    }
}
