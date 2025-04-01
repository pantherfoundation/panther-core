// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../plugins/PluginDataDecoderLib.sol";

contract MockPluginDataDecoder {
    using PluginDataDecoderLib for bytes;

    function testExtractPluginAddress(
        bytes memory data
    ) external pure returns (address) {
        return data.extractPluginAddress();
    }

    function testDecodeUniswapV3RouterExactInputSingleData(
        bytes memory data
    )
        external
        pure
        returns (
            uint32 deadline,
            uint96 amountOutMinimum,
            uint24 fee,
            uint160 sqrtPriceLimitX96
        )
    {
        return data.decodeUniswapV3RouterExactInputSingleData();
    }

    function testDecodeUniswapV3RouterExactInputData(
        bytes memory data
    )
        external
        pure
        returns (uint32 deadline, uint96 amountOutMinimum, bytes memory path)
    {
        return data.decodeUniswapV3RouterExactInputData();
    }

    function testDecodeUniswapV3PoolData(
        bytes memory data
    ) external pure returns (address poolAddress, uint160 sqrtPriceLimitX96) {
        return data.decodeUniswapV3PoolData();
    }

    function testDecodeQuickswapRouterExactInputSingleData(
        bytes memory data
    ) external pure returns (uint96 amountOutMin, uint32 deadline) {
        return data.decodeQuickswapRouterExactInputSingleData();
    }

    function testDecodeQuickswapRouterExactInputData(
        bytes memory data
    )
        external
        pure
        returns (uint96 amountOutMin, uint32 deadline, address[] memory path)
    {
        return data.decodeQuickswapRouterExactInputData();
    }
}
