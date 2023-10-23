// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
// slither-disable-next-line solc-version
pragma solidity ^0.8.16;

library UtilsLib {
    function safe24(uint256 n) internal pure returns (uint24) {
        require(n < 2 ** 24, "UNSAFE24");
        return uint24(n);
    }

    function safe32(uint256 n) internal pure returns (uint32) {
        require(n < 2 ** 32, "UNSAFE32");
        return uint32(n);
    }

    function safe64(uint256 n) internal pure returns (uint64) {
        require(n < 2 ** 64, "UNSAFE64");
        return uint64(n);
    }

    function safe96(uint256 n) internal pure returns (uint96) {
        require(n < 2 ** 96, "UNSAFE96");
        return uint96(n);
    }

    function safe128(uint256 n) internal pure returns (uint128) {
        require(n < 2 ** 128, "UNSAFE128");
        return uint128(n);
    }

    function safe160(uint256 n) internal pure returns (uint160) {
        require(n < 2 ** 160, "UNSAFE160");
        return uint160(n);
    }

    function safe32TimeNow() internal view returns (uint32) {
        uint256 t = block.timestamp;
        require(t < 2 ** 32, "UNSAFE32TIME");
        return uint32(t);
    }

    function safe32BlockNow() internal view returns (uint32) {
        uint256 b = block.number;
        require(b < 2 ** 32, "UNSAFE32BLOCK");
        return uint32(b);
    }

    function revertZeroAddress(address account) internal pure {
        require(account != address(0), "UNEXPECTED_ZERO_ADDRESS");
    }
}
