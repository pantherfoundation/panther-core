// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../vault/StealthExec.sol";

contract MockStealthExecutor {
    using StealthExec for bytes32;

    event DEBUG(address);

    function internalStealthCall(
        bytes32 salt,
        address to,
        bytes memory data,
        uint256 value
    ) external returns (address) {
        address stealth = salt.stealthCall(to, data, value);
        emit DEBUG(stealth);
        return stealth;
    }

    function internalGetStealthAddr(
        bytes32 salt,
        address to,
        bytes memory data
    ) external view returns (address) {
        return salt.getStealthAddr(to, data);
    }
}
