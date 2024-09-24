// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import { APP_STORAGE_END_GAP } from "./Constants.sol";

abstract contract AppStorage {
    bytes32 internal forestRoot;

    bytes32 internal staticRoot;

    bytes32[APP_STORAGE_END_GAP] private _endGap;
}
