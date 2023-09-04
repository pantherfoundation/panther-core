// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

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
