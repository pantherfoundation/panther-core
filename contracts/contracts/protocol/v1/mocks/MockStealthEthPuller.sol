// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../vault/StealthEthPull.sol";

contract MockStealthPuller {
    using StealthEthPull for bytes32;

    function internalStealthPullEthBalance(
        bytes32 salt
    ) external returns (address) {
        return salt.stealthPullEthBalance();
    }

    function internalGetStealthAddr(
        bytes32 salt
    ) external view returns (address) {
        return salt.getStealthAddr();
    }
}
