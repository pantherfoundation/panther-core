// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IBalanceViewer {
    function getBalance(
        uint8 tokenType,
        address token,
        uint256 tokenId
    ) external view returns (uint256 balance);
}
