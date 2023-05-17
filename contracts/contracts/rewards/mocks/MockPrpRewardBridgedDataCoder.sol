// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import "../actions/PrpRewardBridgedDataCoder.sol";

contract MockPrpRewardBridgedDataCoder is PrpRewardBridgedDataCoder {
    function internalEncodeBridgedData(
        uint32 _nonce,
        bytes4 prpGrantType,
        bytes32 secret
    ) external pure returns (bytes memory content) {
        return _encodeBridgedData(_nonce, prpGrantType, secret);
    }

    function internalDecodeBridgedData(bytes memory content)
        external
        pure
        returns (
            uint256 _nonce,
            bytes4 prpGrantType,
            bytes memory secret
        )
    {
        return _decodeBridgedData(content);
    }
}
