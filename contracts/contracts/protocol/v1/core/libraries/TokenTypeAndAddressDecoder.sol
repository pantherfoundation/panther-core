// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "./../../../../common/UtilsLib.sol";

library TokenTypeAndAddressDecoder {
    using UtilsLib for uint256;

    function getTokenTypeAndAddress(
        uint256 tokenTypeAndAddress
    ) internal pure returns (uint8 tokenType, address tokenAddress) {
        // 8 MSB
        tokenType = (tokenTypeAndAddress >> 160).safe8();

        // 160 LSB
        tokenAddress = (tokenTypeAndAddress & type(uint160).max).safeAddress();
    }
}
