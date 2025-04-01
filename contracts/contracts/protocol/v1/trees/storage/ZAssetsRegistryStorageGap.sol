// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import { Z_ASSETS_START_GAP } from "./Constants.sol";

abstract contract ZAssetsRegistryStorageGap {
    bytes32[Z_ASSETS_START_GAP] private _startGap;
}
