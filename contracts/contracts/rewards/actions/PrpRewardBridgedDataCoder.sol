// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

/***
 * @title PrpRewardBridgedDataCoder
 * @dev It encode (pack) and decodes (unpack) messages for bridging them between networks
 */
abstract contract PrpRewardBridgedDataCoder {
    function _encodeBridgedData(
        uint32 _nonce,
        bytes4 prpGrantType,
        bytes32 secret
    ) internal pure returns (bytes memory content) {
        content = abi.encodePacked(_nonce, prpGrantType, secret);
    }

    // For efficiency we use "packed" (rather than "ABI") encoding.
    // It results in shorter data, but requires custom unpack function.
    function _decodeBridgedData(bytes memory content)
        internal
        pure
        returns (
            uint256 _nonce,
            bytes4 prpGrantType,
            bytes memory secret
        )
    {
        require(content.length == 40, "PBD: WRONG_LENGTH");

        _nonce =
            (uint256(uint8(content[0])) << 24) |
            (uint256(uint8(content[1])) << 16) |
            (uint256(uint8(content[2])) << 8) |
            (uint256(uint8(content[3])));

        prpGrantType = bytes4(
            uint32(
                (uint256(uint8(content[4])) << 24) |
                    (uint256(uint8(content[5])) << 16) |
                    (uint256(uint8(content[6])) << 8) |
                    uint256(uint8(content[7]))
            )
        );

        uint256 curPos = 8;
        uint256 msgLength = content.length - curPos;

        secret = new bytes(msgLength);

        if (msgLength > 0) {
            uint256 i = 0;
            while (i < msgLength) {
                secret[i++] = content[curPos++];
            }
        }

        // // solhint-disable-next-line no-inline-assembly
        // assembly {
        //     prpGrantee := div(
        //         mload(add(add(content, 0x20), curPos)),
        //         0x1000000000000000000000000
        //     )
        // }
    }
}
