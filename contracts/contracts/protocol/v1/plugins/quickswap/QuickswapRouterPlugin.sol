// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./../../DeFi/uniswap/interfaces/IUniswapV2Router.sol";
import "./../../DeFi/uniswap/interfaces/IUniswapV2Factory.sol";
import "./../../DeFi/uniswap/interfaces/IUniswapV2Pair.sol";
import "./../../core/interfaces/IPlugin.sol";

import "../TokenPairResolverLib.sol";
import "../PluginDataDecoderLib.sol";
import "../TokenApprovalLib.sol";

contract QuickswapRouterPlugin {
    using TokenPairResolverLib for PluginData;
    using PluginDataDecoderLib for bytes;
    using TokenApprovalLib for address;

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

        if (pair != address(0)) {
            return
                amountOut = _getAmountOutSinglePair(
                    tokenIn,
                    tokenOut,
                    amountIn
                );
        }

        address tokenInNativePair = IUniswapV2Factory(QUICKSWAP_FACTORY)
            .getPair(tokenIn, WETH);

        address tokenOutNativePair = IUniswapV2Factory(QUICKSWAP_FACTORY)
            .getPair(tokenOut, WETH);

        if (
            tokenInNativePair != address(0) && tokenOutNativePair != address(0)
        ) {
            return
                amountOut = _getAmountsOutMultiPair(
                    tokenIn,
                    tokenOut,
                    amountIn
                );
        }
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        uint96 amountOutMin;
        uint32 deadline;
        address[] memory completeSwapPath;

        uint96 amountIn = pluginData.amountIn;

        (address tokenIn, address tokenOut) = pluginData.getTokenInAndTokenOut(
            WETH
        );

        uint256 nativeInputAmount = tokenIn
            .approveInputAmountOrReturnNativeInputAmount(
                pluginData.tokenType,
                QUICKSWAP_ROUTER,
                amountIn
            );

        if (
            pluginData.data.length ==
            QUICKSWAP_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH
        ) {
            (amountOutMin, deadline) = pluginData
                .data
                .decodeQuickswapRouterExactInputSingleData();

            completeSwapPath = _generateCompleteSwapPath(tokenIn, tokenOut);
        } else {
            address[] memory path;

            (amountOutMin, deadline, path) = pluginData
                .data
                .decodeQuickswapRouterExactInputData();

            completeSwapPath = _generateCompleteSwapPath(
                path,
                tokenIn,
                tokenOut
            );
        }

        amountOut = _execute(
            amountIn,
            nativeInputAmount,
            amountOutMin,
            deadline,
            completeSwapPath
        );
    }

    function _execute(
        uint256 amountIn,
        uint256 nativeInputAmount,
        uint256 amountOutMin,
        uint32 deadline,
        address[] memory path
    ) public payable returns (uint256 amountOut) {
        if (path[0] == WETH) {
            amountOut = _swapExactETHForTokens(
                nativeInputAmount,
                amountOutMin,
                deadline,
                path
            );
        } else if (path[path.length - 1] == WETH) {
            amountOut = _swapExactTokensForETH(
                amountIn,
                amountOutMin,
                deadline,
                path
            );
        } else {
            amountOut = _swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                deadline,
                path
            );
        }
    }

    function _swapExactETHForTokens(
        uint256 nativeInputAmount,
        uint256 amountOutMin,
        uint32 deadline,
        address[] memory path
    ) private returns (uint256 amountOut) {
        uint256 pathLength = path.length;
        uint256[] memory _amounts = new uint256[](pathLength);

        try
            IUniswapV2Router(QUICKSWAP_ROUTER).swapExactETHForTokens{
                value: nativeInputAmount
            }(amountOutMin, path, VAULT, deadline)
        returns (uint256[] memory amounts) {
            _amounts = amounts;
        } catch Error(string memory reason) {
            revert(reason);
        }

        amountOut = _amounts[pathLength - 1];
    }

    function _swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        uint32 deadline,
        address[] memory path
    ) private returns (uint256 amountOut) {
        uint256 pathLength = path.length;
        uint256[] memory _amounts = new uint256[](pathLength);

        try
            IUniswapV2Router(QUICKSWAP_ROUTER).swapExactTokensForETH(
                amountIn,
                amountOutMin,
                path,
                VAULT,
                deadline
            )
        returns (uint256[] memory amounts) {
            _amounts = amounts;
        } catch Error(string memory reason) {
            revert(reason);
        }

        amountOut = _amounts[pathLength - 1];
    }

    function _swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        uint32 deadline,
        address[] memory path
    ) private returns (uint256 amountOut) {
        uint256 pathLength = path.length;
        uint256[] memory _amounts = new uint256[](pathLength);

        try
            IUniswapV2Router(QUICKSWAP_ROUTER).swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                VAULT,
                deadline
            )
        returns (uint256[] memory amounts) {
            _amounts = amounts;
        } catch Error(string memory reason) {
            revert(reason);
        }

        amountOut = _amounts[pathLength - 1];
    }

    function _generateCompleteSwapPath(
        address[] memory _path,
        address _tokenIn,
        address _tokenOut
    ) private pure returns (address[] memory completeSwapPath) {
        uint256 numTokens = 2 + _path.length;

        completeSwapPath = new address[](numTokens);
        completeSwapPath[0] = _tokenIn; // first index
        completeSwapPath[numTokens - 1] = _tokenOut; // last index

        // adding tokens at index `1` to index `one before the last`
        for (uint256 i = 1; i < numTokens - 1; ) {
            completeSwapPath[i] = _path[i - 1];
            unchecked {
                ++i;
            }
        }
    }

    function _generateCompleteSwapPath(
        address _tokenIn,
        address _tokenOut
    ) private pure returns (address[] memory completeSwapPath) {
        completeSwapPath = new address[](2);

        completeSwapPath[0] = _tokenIn; // first index
        completeSwapPath[1] = _tokenOut; // last index
    }

    function _getAmountOutSinglePair(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private view returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amountsOut = IUniswapV2Router(QUICKSWAP_ROUTER)
            .getAmountsOut(amountIn, path);

        amountOut = amountsOut[amountsOut.length - 1];
    }

    function _getAmountsOutMultiPair(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private view returns (uint256 amountOut) {
        address[] memory path = new address[](3);
        path[0] = tokenIn;
        path[1] = WETH;
        path[2] = tokenOut;

        uint256[] memory amountsOut = IUniswapV2Router(QUICKSWAP_ROUTER)
            .getAmountsOut(amountIn, path);

        amountOut = amountsOut[amountsOut.length - 1];
    }

    receive() external payable {}
}
