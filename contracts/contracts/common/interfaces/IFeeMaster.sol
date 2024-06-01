// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IFeeMaster {
    function payOff(address receiver) external;

    function cachedNativeRateInZkp() external view returns (uint256);

    function debts(
        address protocol,
        address token
    ) external view returns (uint256);
}
