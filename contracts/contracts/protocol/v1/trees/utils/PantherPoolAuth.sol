// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

abstract contract PantherPoolAuth {
    address public immutable PANTHER_POOL;

    constructor(address pantherPool) {
        PANTHER_POOL = pantherPool;
    }

    modifier onlyPantherPool() {
        require(msg.sender == PANTHER_POOL, "only panther pool");
        _;
    }
}
