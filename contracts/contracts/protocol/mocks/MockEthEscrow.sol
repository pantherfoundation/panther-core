// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

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
