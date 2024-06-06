// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeFi/uniswap/interfaces/IQuoterV2.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3Pool.sol";
import "../DeFi/uniswap/interfaces/ISwapRouter.sol";
import "../interfaces/IPlugin.sol";

import "../../../common/TransferHelper.sol";
import "./PluginLib.sol";

contract UniswapV3RouterPlugin {
    using TransferHelper for address;
    using PluginLib for bytes;

    address public immutable UNISWAP_ROUTER;
    address public immutable UNISWAP_QUOTERV2;
    address public immutable VAULT;

    uint24[4] public feeTiers = [100, 500, 3000, 10000];

    constructor(address uniswapRouter, address uniswapQuoterV2, address vault) {
        require(
            uniswapRouter != address(0) &&
                uniswapQuoterV2 != address(0) &&
                vault != address(0),
            "init: zero address"
        );

        UNISWAP_ROUTER = uniswapRouter;
        UNISWAP_QUOTERV2 = uniswapQuoterV2;
        VAULT = vault;
    }

    function getSqrtPriceX96(
        address pool
    ) external view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    /// @dev  quoteExactInputSingle is not gas efficient and should be called offchain using staticCall
    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory params
    )
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        (
            amountOut,
            sqrtPriceX96After,
            initializedTicksCrossed,
            gasEstimate
        ) = IQuoterV2(UNISWAP_QUOTERV2).quoteExactInputSingle(params);
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        (
            uint32 deadline,
            uint96 amountOutMinimum,
            uint24 fee,
            uint160 sqrtPriceLimitX96
        ) = pluginData.data.decodeUniswapRouterData();

        if (msg.value == 0) {
            pluginData.tokenIn.safeApprove(UNISWAP_ROUTER, pluginData.amountIn);
        }

        ISwapRouter.ExactInputSingleParams
            memory pluginParamsParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: pluginData.tokenIn,
                tokenOut: pluginData.tokenOut,
                amountIn: pluginData.amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: sqrtPriceLimitX96,
                deadline: deadline,
                fee: fee,
                recipient: VAULT
            });

        try
            ISwapRouter(UNISWAP_ROUTER).exactInputSingle{ value: msg.value }(
                pluginParamsParams
            )
        returns (uint256 amount) {
            amountOut = amount;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    // /// @dev  getTokenInputSwapInfos  should be called offchain using staticCall
    // function getTokenInputSwapInfos(
    //     address tokenIn,
    //     address tokenOut,
    //     uint256 amountToSwap,
    //     uint160 minimumSqrtPrice
    // ) external returns (SwapInfo[] memory swapInfos) {
    //     swapInfos = new SwapInfo[](feeTiers.length);

    //     for (uint256 i = 0; i < feeTiers.length; i++) {
    //         address pool = IUniswapV3Factory(FACTORY).getPool(
    //             tokenIn,
    //             tokenOut,
    //             feeTiers[i]
    //         );
    //         uint128 liquidity = 0;
    //         bool sufficientLiquidity = false;

    //         if (pool != address(0)) {
    //             liquidity = IUniswapV3Pool(pool).liquidity();
    //             (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool)
    //                 .slot0();

    //             address token0 = IUniswapV3Pool(pool).token0();

    //             if (tokenIn == token0) {
    //                 uint256 reserve0 = (liquidity * uint256(sqrtPriceX96)) >>
    //                     96;
    //                 sufficientLiquidity = reserve0 >= amountToSwap;
    //             } else {
    //                 uint256 reserve1 = liquidity <<
    //                     (96 / uint256(sqrtPriceX96));
    //                 sufficientLiquidity = reserve1 >= amountToSwap;
    //             }

    //             try
    //                 IQuoterV2(QUOTER).quoteExactInputSingle(
    //                     IQuoterV2.QuoteExactInputSingleParams({
    //                         tokenIn: tokenIn,
    //                         tokenOut: tokenOut,
    //                         amountIn: amountToSwap,
    //                         fee: feeTiers[i],
    //                         sqrtPriceLimitX96: minimumSqrtPrice
    //                     })
    //                 )
    //             returns (
    //                 uint256 amountOut,
    //                 uint160 sqrtRatioX96,
    //                 uint32 initializedTicksCrossed,
    //                 uint256 gasEstimate
    //             ) {
    //                 swapInfos[i] = SwapInfo({
    //                     pool: pool,
    //                     feeTier: feeTiers[i],
    //                     amountOut: amountOut,
    //                     sqrtRatioX96: sqrtRatioX96,
    //                     initializedTicksCrossed: initializedTicksCrossed,
    //                     gasEstimate: gasEstimate,
    //                     liquidity: IUniswapV3Pool(pool).liquidity(),
    //                     sufficientLiquidity: sufficientLiquidity
    //                 });
    //             } catch {
    //                 continue;
    //             }
    //         }
    //     }
    // }
}
