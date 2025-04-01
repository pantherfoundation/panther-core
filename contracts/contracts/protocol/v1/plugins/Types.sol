// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// slither-disable-next-line solc-version
pragma solidity ^0.8.19;

struct PluginData {
    uint168 tokenInTypeAndAddress;
    uint168 tokenOutTypeAndAddress;
    uint96 amountIn;
    bytes data;
}
