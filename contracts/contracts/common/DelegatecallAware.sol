// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { SelfAddressAware } from "./SelfAddressAware.sol";

string constant ERR_NO_CALLS = "DA:E1";
string constant ERR_ZERO_TO = "DA:E2";
string constant ERR_NOT_SELF = "DA:E3";

abstract contract DelegatecallAware is SelfAddressAware {
    /// @dev Reverts if not DELEGATECALL'ed
    modifier onlyDelegatecalled() {
        require(isDelegatecalled(), ERR_NO_CALLS);
        _;
    }

    /// @dev Reverts if not DELEGATECALL'ed
    modifier onlyDelegatecalledAfterSelfCall() {
        require(msg.sender == SELF, ERR_NOT_SELF);
        require(isDelegatecalled(), ERR_NO_CALLS);
        _;
    }

    /// @dev Returns true if DELEGATECALL'ed
    function isDelegatecalled() internal view returns (bool) {
        return address(this) != SELF;
    }
}
