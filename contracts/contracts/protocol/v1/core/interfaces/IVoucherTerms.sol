// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { VoucherTerms } from "../facets/prpVoucherController/Types.sol";

/**
 * @title IVoucherTerms
 * @notice Interface for reading `VoucherTerms`
 */
interface IVoucherTerms {
    /**
     * @notice Gets the voucher terms for a specific contract and voucher type
     * @param contractAddress The address of the contract allowed to generate vouchers
     * @param voucherType The type identifier for the voucher
     * @return terms The voucher terms structure
     */
    function getVoucherTerms(
        address contractAddress,
        bytes4 voucherType
    ) external view returns (VoucherTerms memory terms);
}
