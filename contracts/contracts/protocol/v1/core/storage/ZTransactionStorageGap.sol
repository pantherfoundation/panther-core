// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import { Z_TRANSACTION_START_GAP } from "./Constants.sol";

abstract contract ZTransactionStorageGap {
    bytes32[Z_TRANSACTION_START_GAP] private _startGap;
}
