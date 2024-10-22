// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../core/libraries/TokenTypeAndAddressDecoder.sol";
import "../plugins/Types.sol";
import { NATIVE_TOKEN_TYPE } from "./../../../common/Constants.sol";

library TokenPairResolverLib {
    using TokenTypeAndAddressDecoder for uint168;

    function getTokenTypesAndAddresses(
        PluginData calldata pluginData,
        address weth
    )
        internal
        pure
        returns (
            uint8 tokenInType,
            address tokenInAddress,
            uint8 tokenOutType,
            address tokenOutAddress
        )
    {
        (tokenInType, tokenInAddress) = pluginData
            .tokenInTypeAndAddress
            .getTokenTypeAndAddress();

        (tokenOutType, tokenOutAddress) = pluginData
            .tokenOutTypeAndAddress
            .getTokenTypeAndAddress();

        if (tokenInType == NATIVE_TOKEN_TYPE) {
            tokenInAddress = weth;
        }

        if (tokenOutType == NATIVE_TOKEN_TYPE) {
            tokenOutAddress = weth;
        }
    }
}
