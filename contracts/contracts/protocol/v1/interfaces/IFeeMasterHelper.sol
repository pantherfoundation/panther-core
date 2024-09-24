// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IFeeMasterHelper {
    /**
     * @dev pays accumulated debts to receiver
     * @param receiver - The address funds to be send to
     * @return sent amount
     */
    function payOff(address receiver) external returns (uint256);

    /**
     * @dev returns FeeMaster's cached native token rate in zkp
     * @return token price
     */
    function cachedNativeRateInZkp() external view returns (uint256);

    /**
     * @dev returns accumulated FeeMaster service provider's debt
     * @param protocol Fee service provider address
     * @param token Token debt to be accounted in
     * @return Current debt
     */
    function debts(
        address protocol,
        address token
    ) external view returns (uint256);
}
