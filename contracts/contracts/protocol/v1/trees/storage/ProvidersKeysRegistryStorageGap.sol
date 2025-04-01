// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import { PROVIDERS_KEYS_START_GAP } from "./Constants.sol";

abstract contract ProvidersKeysRegistryStorageGap {
    bytes32[PROVIDERS_KEYS_START_GAP] private _startGap;
}
