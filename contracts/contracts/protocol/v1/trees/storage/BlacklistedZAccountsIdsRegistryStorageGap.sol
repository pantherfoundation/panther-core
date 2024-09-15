// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import { BLACKLISTED_ZACCOUNTS_IDS_START_GAP } from "./Constants.sol";

abstract contract BlacklistedZAccountsIdsRegistryStorageGap {
    bytes32[BLACKLISTED_ZACCOUNTS_IDS_START_GAP] private _startGap;
}
