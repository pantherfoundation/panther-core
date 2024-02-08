// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

interface IZAccountsRegistry {
    function isZAccountWhitelisted(
        address _masterEOA
    ) external view returns (bool isWhitelisted);
}
