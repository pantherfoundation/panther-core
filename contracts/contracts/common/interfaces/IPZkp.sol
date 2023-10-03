// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IPZkp {
    function minter() external view returns (address);

    function setMinter(address _minter) external;

    function deposit(address user, bytes calldata depositData) external;
}
