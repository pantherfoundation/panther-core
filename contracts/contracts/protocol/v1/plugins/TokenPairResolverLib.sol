// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../plugins/Types.sol";
import { NATIVE_TOKEN } from "./../../../common/Constants.sol";

library TokenPairResolverLib {
    function getTokenInAndTokenOut(
        PluginData calldata pluginData,
        address weth
    ) internal pure returns (address tokenIn, address tokenOut) {
        tokenIn = pluginData.tokenIn;
        tokenOut = pluginData.tokenOut;

        if (tokenIn == NATIVE_TOKEN) {
            tokenIn = weth;
        }

        if (tokenOut == NATIVE_TOKEN) {
            tokenOut = weth;
        }
    }
}
