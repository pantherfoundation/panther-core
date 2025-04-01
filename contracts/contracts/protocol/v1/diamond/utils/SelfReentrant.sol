// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";

/**
 * @title SelfReentrant
 * @notice Provides a reentrancy guard with support for internal calls.
 * @dev This abstract contract includes a self-reentrant modifier that allows contract self-calls
 * while preventing external reentrant calls. Utilizes the LibDiamond storage for reentrancy status.
 */
abstract contract SelfReentrant {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /**
     * @notice Modifier to prevent reentrant calls except from within the same contract.
     * @dev Allows internal calls (calls from the contract itself) to bypass the reentrancy check.
     * Reverts if an external call is detected while the contract is in an "ENTERED" state.
     * Utilizes LibDiamond for managing reentrancy status.
     */
    modifier selfReentrant() {
        if (msg.sender == address(this)) _;
        else {
            LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
            // Being called right after deployment, when _reentrancyStatus is 0 ,
            // it does not revert (which is expected behaviour)
            require(LibDiamond.reentrancyStatus() != ENTERED, "reentrant call");

            // Any calls to nonReentrant after this point will fail
            LibDiamond.setReentrancyStatus(ENTERED);

            _;

            // By storing the original value once again, a refund is triggered (see
            // https://eips.ethereum.org/EIPS/eip-2200)
            LibDiamond.setReentrancyStatus(NOT_ENTERED);
        }
    }
}
