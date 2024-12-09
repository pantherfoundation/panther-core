// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
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
        uint8 scaleFactor
    ) internal pure returns (uint96) {
        require(scaleFactor <= 19, "too high scale factor");

        uint64 scale = uint64((10 ** scaleFactor));
        return (uint96(tokenIdRangeSize) << 64) | scale;
    }
}
