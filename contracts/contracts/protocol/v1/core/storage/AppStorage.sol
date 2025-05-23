// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import { APP_STORAGE_END_GAP } from "./Constants.sol";

abstract contract AppStorage {
    mapping(uint16 => uint160) internal circuitIds;

    mapping(address => uint256) internal feeMasterDebt;

    mapping(bytes32 => uint256) internal isSpent;

    uint32 internal maxBlockTimeOffset;

    bytes32[APP_STORAGE_END_GAP] private _endGap;
}
