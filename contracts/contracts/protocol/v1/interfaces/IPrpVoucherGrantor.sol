// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

/**
 * @title IPrpVoucherGrantor
 * @notice Interface for the `PrpVoucherGrantor` contract
 */
interface IPrpVoucherGrantor {
    function generateRewards(
        bytes32 _secretHash,
        uint64 _amount,
        bytes4 _voucherType
    ) external returns (uint256);
}
