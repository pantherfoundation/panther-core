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
    function _decodeBridgedData(
        bytes memory content
    )
        internal
        pure
        returns (uint256 nonce, bytes4 prpGrantType, bytes32 secret)
    {
        require(content.length == 68, "PBD: WRONG_LENGTH");

        nonce =
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

        secret = bytes32(
            (uint256(uint8(content[8])) << 24) |
                (uint256(uint8(content[9])) << 16) |
                (uint256(uint8(content[10])) << 8) |
                (uint256(uint8(content[11])))
        );
    }
}
