// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../core/interfaces/IPlugin.sol";
import "../../core/libraries/TokenTypeAndAddressDecoder.sol";

import "../../../../common/TransferHelper.sol";
import "../../DeFi/UniswapV3FlashSwap.sol";
import "../PluginDataDecoderLib.sol";

import { NATIVE_TOKEN_TYPE } from "../../../../common/Constants.sol";

contract UniswapV3PoolPlugin {
    using TokenTypeAndAddressDecoder for uint168;
    using PluginDataDecoderLib for bytes;
    using UniswapV3FlashSwap for address;
    using TransferHelper for address;
    using TransferHelper for address payable;

    address public immutable WETH;
    address public immutable VAULT;

    constructor(address wEth, address vault) {
        WETH = wEth;
        VAULT = vault;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        (address pool, address token0, address token1) = abi.decode(
            data,
            (address, address, address)
        );
        require(msg.sender == pool, "uniswapV3SwapCallback::Invalid sender");

        if (amount0Delta > 0) token0.safeTransfer(pool, uint256(amount0Delta));
        if (amount1Delta > 0) token1.safeTransfer(pool, uint256(amount1Delta));
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        (address pool, uint160 sqrtPriceLimitX96) = pluginData
            .data
            .decodeUniswapV3PoolData();

        (uint8 tokenInType, address tokenInAddress) = pluginData
            .tokenInTypeAndAddress
            .getTokenTypeAndAddress();

        (uint8 tokenOutType, address tokenOutAddress) = pluginData
            .tokenInTypeAndAddress
            .getTokenTypeAndAddress();

        if (tokenInType == NATIVE_TOKEN_TYPE) {
            WETH.convertNativeToWNative(pluginData.amountIn);
        }

        amountOut = pool.swapExactInput(
            tokenInAddress,
            tokenOutAddress,
            pluginData.amountIn,
            sqrtPriceLimitX96
        );

        if (tokenOutType == NATIVE_TOKEN_TYPE) {
            WETH.convertWNativeToNative(amountOut);
            VAULT.safeTransferETH(amountOut);
        } else {
            tokenOutAddress.safeTransfer(VAULT, amountOut);
        }
    }

    receive() external payable {}
}
