// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256) external;
}
