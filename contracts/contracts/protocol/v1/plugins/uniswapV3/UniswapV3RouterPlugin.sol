// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../DeFi/uniswap/interfaces/IQuoterV2.sol";
import "../../DeFi/uniswap/interfaces/ISwapRouter.sol";
import "../../interfaces/IPlugin.sol";

import "../TokenPairResolverLib.sol";
import "../PluginDataDecoderLib.sol";
import "../TokenApprovalLib.sol";

contract UniswapV3RouterPlugin {
    using TokenPairResolverLib for PluginData;
    using PluginDataDecoderLib for bytes;
    using TokenApprovalLib for address;

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
    ) public returns (Quote[4] memory quotes) {
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

    function quoteExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (bytes memory path, uint256 amountOut) {
        Quote[4] memory tokenInToNativeQuotes = quoteExactInputSingle(
            tokenIn,
            WETH,
            amountIn
        );

        (uint24 feeForTokenInNativePool, ) = _findOptimalSwapParameters(
            tokenInToNativeQuotes
        );

        //
        Quote[4] memory nativeToTokenOutQuotes = quoteExactInputSingle(
            WETH,
            tokenOut,
            amountIn
        );

        uint24 feeForTokenOutNativePool;

        (feeForTokenOutNativePool, amountOut) = _findOptimalSwapParameters(
            nativeToTokenOutQuotes
        );

        // This path must be passed to `execute()` method. the `tokenIn` and `tokenOut`
        // will be added by that methods
        path = abi.encodePacked(
            feeForTokenInNativePool,
            WETH,
            feeForTokenOutNativePool
        );
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        uint8 tokenType = pluginData.tokenType;
        uint96 amountIn = pluginData.amountIn;
        bytes memory data = pluginData.data;

        (address tokenIn, address tokenOut) = pluginData.getTokenInAndTokenOut(
            WETH
        );

        uint256 nativeInputAmount = tokenIn
            .approveInputAmountOrReturnNativeInputAmount(
                tokenType,
                UNISWAP_ROUTER,
                amountIn
            );

        amountOut = _execute(
            tokenIn,
            tokenOut,
            amountIn,
            nativeInputAmount,
            data
        );
    }

    function _execute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 nativeAmount,
        bytes memory data
    ) private returns (uint256 amountOut) {
        if (data.length == UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH) {
            (
                uint32 deadline,
                uint96 amountOutMinimum,
                uint24 fee,
                uint160 sqrtPriceLimitX96
            ) = data.decodeUniswapV3RouterExactInputSingleData();

            ISwapRouter.ExactInputSingleParams
                memory pluginParamsParams = ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMinimum,
                    sqrtPriceLimitX96: sqrtPriceLimitX96,
                    deadline: deadline,
                    fee: fee,
                    recipient: VAULT
                });

            _executeExactInputSignle(pluginParamsParams, nativeAmount);
        } else {
            (uint32 deadline, uint96 amountOutMinimum, bytes memory path) = data
                .decodeUniswapV3RouterExactInputData();

            // tokenIn + {fee+address1+fee+...+fee+addressN+fee} + tokenOut
            bytes memory completeSwapPath = abi.encodePacked(
                tokenIn,
                path,
                tokenOut
            );

            ISwapRouter.ExactInputParams memory pluginParams = ISwapRouter
                .ExactInputParams({
                    path: completeSwapPath,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMinimum,
                    deadline: deadline,
                    recipient: VAULT
                });

            amountOut = _executeExactInput(pluginParams, nativeAmount);
        }
    }

    function _executeExactInputSignle(
        ISwapRouter.ExactInputSingleParams memory exactInputSingleParams,
        uint256 nativeAmount
    ) private returns (uint256 amountOut) {
        try
            ISwapRouter(UNISWAP_ROUTER).exactInputSingle{ value: nativeAmount }(
                exactInputSingleParams
            )
        returns (uint256 amount) {
            amountOut = amount;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _executeExactInput(
        ISwapRouter.ExactInputParams memory exactInputParams,
        uint256 nativeAmount
    ) private returns (uint256 amountOut) {
        try
            ISwapRouter(UNISWAP_ROUTER).exactInput{ value: nativeAmount }(
                exactInputParams
            )
        returns (uint256 amount) {
            amountOut = amount;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _findOptimalSwapParameters(
        Quote[4] memory quotes
    ) private pure returns (uint24 fee, uint256 amountOut) {
        // first quote has to lowest fee (500), so it may gives us more output token amount.
        fee = quotes[0].fee;
        amountOut = quotes[0].amountOut;

        // checking if pools with other fees gives us better amountOut
        for (uint256 i = 1; i < quotes.length; i++) {
            if (quotes[i].amountOut > amountOut) fee = quotes[i].fee;
        }
    }

    receive() external payable {}
}
