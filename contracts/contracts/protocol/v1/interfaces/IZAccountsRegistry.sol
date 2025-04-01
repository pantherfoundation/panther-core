// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IZAccountsRegistry {
    function isZAccountWhitelisted(
        address _masterEOA
    ) external view returns (bool isWhitelisted);
}
