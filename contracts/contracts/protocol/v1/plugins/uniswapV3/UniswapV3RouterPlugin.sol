// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../DeFi/uniswap/interfaces/IQuoterV2.sol";
import "../../DeFi/uniswap/interfaces/ISwapRouter.sol";
import "../../interfaces/IPlugin.sol";

import { ERC20_TOKEN_TYPE, NATIVE_TOKEN_TYPE, NATIVE_TOKEN } from "../../../../common/Constants.sol";
import "../../../../common/TransferHelper.sol";
import "../PluginLib.sol";

contract UniswapV3RouterPlugin {
    using TransferHelper for address;
    using PluginLib for bytes;

    address public immutable UNISWAP_ROUTER;
    address public immutable UNISWAP_QUOTERV2;
    address public immutable WETH;
    address public immutable VAULT;

    struct Quote {
        uint24 fee;
        uint256 amountOut;
        uint160 sqrtPriceX96After;
        uint32 initializedTicksCrossed;
        uint256 gasEstimate;
    }

    constructor(address uniswapRouter, address uniswapQuoterV2, address vault) {
        require(
            uniswapRouter != address(0) &&
                uniswapQuoterV2 != address(0) &&
                vault != address(0),
            "init: zero address"
        );

        UNISWAP_ROUTER = uniswapRouter;
        UNISWAP_QUOTERV2 = uniswapQuoterV2;
        WETH = ISwapRouter(uniswapRouter).WETH9();
        VAULT = vault;
    }

    function getFeeTiers() public pure returns (uint24[3] memory feeTiers) {
        feeTiers[0] = 500;
        feeTiers[1] = 3000;
        feeTiers[2] = 10000;
    }

    /// @dev  quoteExactInputSingle is not gas efficient and should be called offchain using staticCall
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (Quote[4] memory quotes) {
        uint24[3] memory feeTiers = getFeeTiers();

        for (uint256 i = 0; i < feeTiers.length; i++) {
            QuoteExactInputSingleParams
                memory params = QuoteExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    fee: feeTiers[i],
                    // Pass 0 since we only want to send static call to router
                    // to receive data regardless of the sqrtPriceLimitX96.
                    sqrtPriceLimitX96: 0
                });

            try
                IQuoterV2(UNISWAP_QUOTERV2).quoteExactInputSingle(params)
            returns (
                uint256 amountOut,
                uint160 sqrtPriceX96After,
                uint32 initializedTicksCrossed,
                uint256 gasEstimate
            ) {
                quotes[i] = Quote({
                    fee: feeTiers[i],
                    amountOut: amountOut,
                    sqrtPriceX96After: sqrtPriceX96After,
                    initializedTicksCrossed: initializedTicksCrossed,
                    gasEstimate: gasEstimate
                });
            } catch {
                quotes[i] = Quote({
                    fee: feeTiers[i],
                    amountOut: 0,
                    sqrtPriceX96After: 0,
                    initializedTicksCrossed: 0,
                    gasEstimate: 0
                });
            }
        }
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        (
            uint32 deadline,
            uint96 amountOutMinimum,
            uint24 fee,
            uint160 sqrtPriceLimitX96
        ) = pluginData.data.decodeUniswapV3RouterData();

        uint8 tokenType = pluginData.tokenType;
        uint96 amountIn = pluginData.amountIn;

        (address tokenIn, address tokenOut) = _getTokenInAndTokenOut(
            pluginData
        );

        uint256 nativeInputAmount = _approveInputAmountOrReturnNativeInputAmount(
                tokenType,
                tokenIn,
                amountIn
            );

        ISwapRouter.ExactInputSingleParams
            memory pluginParamsParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: pluginData.amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                deadline: deadline,
                fee: fee,
                recipient: VAULT
            });

        try
            ISwapRouter(UNISWAP_ROUTER).exactInputSingle{
                value: nativeInputAmount
            }(pluginParamsParams)
        returns (uint256 amount) {
            amountOut = amount;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _getTokenInAndTokenOut(
        PluginData calldata pluginData
    ) private view returns (address tokenIn, address tokenOut) {
        tokenIn = pluginData.tokenIn;
        tokenOut = pluginData.tokenOut;

        if (tokenIn == NATIVE_TOKEN) {
            tokenIn = WETH;
        }

        if (tokenOut == NATIVE_TOKEN) {
            tokenOut = WETH;
        }
    }

    function _approveInputAmountOrReturnNativeInputAmount(
        uint8 tokenType,
        address tokenIn,
        uint96 amountIn
    ) private returns (uint256 nativeInputAmount) {
        if (tokenType == ERC20_TOKEN_TYPE) {
            tokenIn.safeApprove(UNISWAP_ROUTER, amountIn);
        }
        if (tokenType == NATIVE_TOKEN_TYPE) {
            nativeInputAmount = amountIn;
        }
    }

    receive() external payable {}
}
