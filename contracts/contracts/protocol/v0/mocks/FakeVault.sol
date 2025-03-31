// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import { LockData } from "../../../common/Types.sol";
import "../interfaces/IVaultV0.sol";

contract FakeVault is IVaultV0 {
    event DebugData(LockData data);

    function lockAsset(LockData calldata data) external override {
        emit DebugData(data);
    }

    function unlockAsset(LockData memory data) external override {
        emit DebugData(data);
    }
}
