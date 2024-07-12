// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IBalanceViewer {
    function getBalance(
        uint8 tokenType,
        address token,
        uint256 tokenId
    ) external view returns (uint256 balance);
}
