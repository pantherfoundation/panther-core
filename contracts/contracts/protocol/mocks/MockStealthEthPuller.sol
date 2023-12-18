// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

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
