// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IPayOff {
    /**
     * @dev Emitted when protocol pays the collected fees
     * @param receiver address of the fee receiver
     * @param token address of the fee token
     * @param amount the amount that is sent
     */
    event PayOff(address receiver, address token, uint256 amount);

    /**
     * @notice Pays off the entire debt owed by the caller in the native token to a specified receiver.
     *
     * @dev This external function allows the caller to settle their entire debt denominated in the native token.
     *      Upon successful execution, the debt is cleared, and the equivalent amount of native tokens is transferred
     *      to the specified receiver through the Panther Pool. The function ensures that the caller has a non-zero debt
     *      before proceeding with the repayment.
     * @param receiver The address that will receive the native tokens equivalent to the debt being repaid.
     *                 - Must be a valid address capable of receiving native tokens.
     *
     * @return debt The total amount of native tokens that was repaid, effectively clearing the caller's debt.
     */
    function payOff(address receiver) external returns (uint256 debt);

    /**
     * @notice Pays off a specified amount of debt owed by the caller in a given token to a designated receiver.
     *
     * @dev This external function enables a caller (provider) to partially or fully settle their debt in a specified ERC20 token.
     *      The function ensures that the caller's existing debt in the chosen token is sufficient to cover the repayment amount.
     *      Upon successful execution, the specified amount is deducted from the caller's debt, and the equivalent token amount
     *      is transferred to the receiver through the Panther Pool.
     *
     *
     * @param tokenAddress The address of the ERC20 token in which the debt is denominated.
     *                     - Must be a valid ERC20 token contract address.
     *
     * @param receiver The address that will receive the tokens equivalent to the debt being repaid.
     *                 - Must be a valid address capable of receiving the specified ERC20 tokens.
     *
     * @param amount The amount of the specified token to repay.
     *               - Must be a positive value.
     *
     * @return debt The updated total debt amount (`uint256`) that the caller owes in the specified token after repayment.
     */
    function payOff(
        address tokenAddress,
        address receiver,
        uint256 amount
    ) external returns (uint256 debt);
}
