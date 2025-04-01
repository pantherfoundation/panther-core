// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../../common/UtilsLib.sol";

library ZAssetEncodingUtils {
    using UtilsLib for uint256;

    function encodeAddressWithType(
        address _address,
        uint8 _type
    ) internal pure returns (uint168) {
        return (uint168(_type) << 160) | uint160(_address);
    }

    function decodeAddressWithType(
        uint168 _tokenAddrAndType
    ) internal pure returns (address _address, uint8 _type) {
        _address = uint256((_tokenAddrAndType & type(uint160).max))
            .safeAddress();

        _type = uint8(_tokenAddrAndType >> 160);
    }

    function encodeTokenIdRangeSizeWithScale(
        uint32 tokenIdRangeSize,
        uint64 scale
    ) internal pure returns (uint96) {
        require(scale > 0, "zero scale");

        return (uint96(tokenIdRangeSize) << 64) | scale;
    }
}
