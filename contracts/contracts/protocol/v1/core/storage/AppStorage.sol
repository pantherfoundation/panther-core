// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import { APP_STORAGE_END_GAP } from "./Constants.sol";

abstract contract AppStorage {
    mapping(uint16 => uint160) public circuitIds;

    mapping(address => uint256) public feeMasterDebt;

    mapping(bytes32 => uint256) public isSpent;

    uint32 public maxBlockTimeOffset;

    bytes32[APP_STORAGE_END_GAP] private _endGap;
}
