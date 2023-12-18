// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { RevertMsgGetter } from "./misc/RevertMsgGetter.sol";

/// @dev If used together with the Multicall, this contract allows atomic execution
/// of a few contract calls (so that, either all calls will be executed together
/// or no calls will be executed) with the `msg.sender` inside these calls, being
/// the account that calls the `function delegatecall` on this contract (it may
/// be called via a proxy only).
contract DelegateCaller is RevertMsgGetter {
    address internal immutable SELF;

    constructor() {
        SELF = address(this);
    }

    function delegatecall(
        address to,
        bytes memory data
    ) external payable returns (bytes memory) {
        // This way this code (i.e. the "implementation") is protected
        // against accidental or hostile destruction. However, a proxy
        // can still self-destruct own context by DELEGATECALL`ing via
        // this code another code, that executes SELFDESTRUCT.
        require(address(this) != SELF, "MD: DELEGATECALL_ONLY");

        require(to != address(0), "MD: ZERO_TO_ADDR");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory result) = to.delegatecall(data);
        if (!success) revert(getRevertMsg(result));
        return result;
    }
}
