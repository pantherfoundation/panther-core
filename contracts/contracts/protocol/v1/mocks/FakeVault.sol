// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { LockData, SaltedLockData } from "../../../common/Types.sol";
import "../interfaces/IVaultV1.sol";

contract FakeVault is IVaultV1 {
    event DebugData(bytes32 data);
    event DebugData(LockData data);
    event DebugSaltedData(SaltedLockData data);

    function lockAssetWithSalt(
        SaltedLockData calldata data
    ) external payable override {
        emit DebugSaltedData(data);
    }

    function lockAsset(LockData calldata data) external payable override {
        emit DebugData(data);
    }

    function unlockAsset(LockData memory data) external override {
        emit DebugData(data);
    }

    function sendEthToEscrow(bytes32 salt) external payable override {
        emit DebugData(salt);
    }

    function withdrawEthFromEscrow(bytes32 salt) external override {
        emit DebugData(salt);
    }

    function getEscrowAddress(
        bytes32,
        address
    ) public view override returns (address escrowAddr) {
        // to silence mutability warning
        this;
        escrowAddr = address(uint160(0x1010));
    }
}
