// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

abstract contract SelfAddressAware {
    address internal immutable SELF;

    constructor() {
        SELF = address(this);
    }
}
