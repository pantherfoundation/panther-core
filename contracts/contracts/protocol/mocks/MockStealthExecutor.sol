// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../vault/StealthExecutor.sol";

contract MockStealthExecutor is StealthExecutor {
    function stealthExec(
        uint256 amount,
        bytes32 salt,
        address to,
        bytes calldata data
    ) external returns (address) {
        return _stealthExec(amount, salt, to, data);
    }
}
