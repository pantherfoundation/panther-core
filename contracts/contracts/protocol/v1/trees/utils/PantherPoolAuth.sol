// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

abstract contract PantherPoolAuth {
    address internal immutable PANTHER_POOL;

    constructor(address pantherPool) {
        PANTHER_POOL = pantherPool;
    }

    modifier onlyPantherPool() {
        require(
            msg.sender == PANTHER_POOL,
            "pantherTrees: unauthorized panther pool"
        );
        _;
    }
}
