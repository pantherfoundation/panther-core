// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

abstract contract SelfAddressAware {
    address internal immutable SELF;

    constructor() {
        SELF = address(this);
    }
}
