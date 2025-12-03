// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity 0.8.19;

/// @dev Struct for storing voucher terms.
/// @param rewardsGranted The total amount (accumulator) of rewards granted
/// for this voucher
/// @param limit The rewards limit of the reward voucher. rewardsGranted <=
//limit
/// @param amount The amount of the reward that voucher generates.
/// @param enabled The status of the voucher terms.
struct VoucherTerms {
    uint64 rewardsGranted;
    uint64 limit;
    uint64 amount;
    bool enabled;
    // rest of the storage slot (uint120) are available for upgrades
    uint56 _reserved;
}
