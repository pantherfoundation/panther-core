// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../DeFi/uniswap/interfaces/IUniswapV2Router.sol";
import "../../DeFi/uniswap/interfaces/IUniswapV2Factory.sol";
import "../../DeFi/uniswap/interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IPlugin.sol";

import { ERC20_TOKEN_TYPE, NATIVE_TOKEN_TYPE, NATIVE_TOKEN } from "../../../../common/Constants.sol";
import "../../../../common/TransferHelper.sol";
import "../PluginLib.sol";

contract QuickswapRouterPlugin {
    using TransferHelper for address;
    using PluginLib for bytes;

    address public immutable QUICKSWAP_ROUTER;
    address public immutable QUICKSWAP_FACTORY;
    address public immutable VAULT;
    address public immutable WETH;

    constructor(
        address quickswapRouter,
        address quickswapFactory,
        address vault,
        address weth
    ) {
        require(
            quickswapRouter != address(0) &&
                quickswapFactory != address(0) &&
                vault != address(0) &&
                weth != address(0),
            "init: zero address"
        );

        QUICKSWAP_ROUTER = quickswapRouter;
        QUICKSWAP_FACTORY = quickswapFactory;
        VAULT = vault;
        WETH = weth;
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        address pair = IUniswapV2Factory(QUICKSWAP_FACTORY).getPair(
            tokenIn,
            tokenOut
        );
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();

        address token0 = IUniswapV2Pair(pair).token0();

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        amountOut = IUniswapV2Router(QUICKSWAP_ROUTER).getAmountOut(
            amountIn,
            reserveIn,
            reserveOut
        );
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        (uint96 amountOutMin, uint32 deadline) = pluginData
            .data
            .decodeQuickswapRouterData();

        if (pluginData.tokenType == ERC20_TOKEN_TYPE) {
            pluginData.tokenIn.safeApprove(
                QUICKSWAP_ROUTER,
                pluginData.amountIn
            );

            address[] memory path = new address[](2);
            path[0] = pluginData.tokenIn;
            path[1] = pluginData.tokenOut;

            IUniswapV2Router(QUICKSWAP_ROUTER).swapExactTokensForTokens(
                pluginData.amountIn,
                amountOutMin,
                path,
                VAULT,
                deadline
            );
        }

        if (pluginData.tokenType == NATIVE_TOKEN_TYPE) {
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = pluginData.tokenOut;

            IUniswapV2Router(QUICKSWAP_ROUTER).swapExactETHForTokens{
                value: pluginData.amountIn
            }(amountOutMin, path, VAULT, deadline);
        }

        if (pluginData.tokenOut == NATIVE_TOKEN) {
            address[] memory path = new address[](2);
            path[0] = pluginData.tokenIn;
            path[1] = WETH;

            IUniswapV2Router(QUICKSWAP_ROUTER).swapExactTokensForETH(
                pluginData.amountIn,
                amountOutMin,
                path,
                VAULT,
                deadline
            );
        }

        // Get amount out from uniswap router call
        amountOut = 0;
    }

    receive() external payable {}
}
