// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IDebtSettlement {
    /**
     * @dev Pays off the debt in native token.
     * @return debt The amount of debt paid off.
     */
    function payOff(address receiver) external returns (uint256 debt);

    /**
     * @dev Pays off the debt in a specific token.
     * @param tokenAddress Address of the token in which the debt is to be paid off.
     * @return debt The amount of debt paid off.
     */
    function payOff(
        address tokenAddress,
        address receiver,
        uint256 amount
    ) external returns (uint256 debt);
}
