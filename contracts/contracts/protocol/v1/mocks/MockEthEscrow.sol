// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../vault/EthEscrow.sol";

contract MockEthEscrow is EthEscrow {
    function internalPullEthFromEscrow(
        bytes32 salt,
        address depositor,
        uint256 value
    ) external {
        pullEthFromEscrow(salt, depositor, value);
    }
}
