// SPDX-License-Identifier: MIT
// slither-disable-next-line solc-version
pragma solidity ^0.8.4;

interface IErc20Min {
    /// @dev ERC-20 `balanceOf`
    function balanceOf(address account) external view returns (uint256);

    /// @dev ERC-20 `transfer`
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @dev ERC-20 `transferFrom`
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}
