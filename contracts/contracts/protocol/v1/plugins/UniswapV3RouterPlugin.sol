// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeFi/uniswap/libraries/CallbackValidation.sol";
import "../DeFi/uniswap/interfaces/IQuoterV2.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3Pool.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3Factory.sol";
import "../DeFi/uniswap/Types.sol";

contract UniswapV3RouterPlugin {
    address public immutable ROUTER;
    address public immutable VAULT;
    address public immutable QUOTER;
    address public immutable FACTORY;

    uint16[] public feeTiers = [500, 3000, 10000];

    constructor(
        address router,
        address vault,
        address quoter,
        address factory
    ) {
        ROUTER = router;
        VAULT = vault;
        QUOTER = quoter;
        FACTORY = factory;
    }

    /// @dev  getQuoterV2InputSingle is not gas efficient and should be called offchain using staticCall
    function getQuoterV2InputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountToSwap
    )
        external
        returns (uint256 amountOut, uint160 sqrtRatioX96, uint256 gasEstimate)
    {
        (amountOut, sqrtRatioX96, , gasEstimate) = IQuoterV2(QUOTER)
            .quoteExactInputSingle(
                IQuoterV2.QuoteExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountToSwap,
                    fee: fee,
                    sqrtPriceLimitX96: 0
                })
            );
    }

    /// @dev  getTokenInputSwapInfos  should be called offchain using staticCall
    function getTokenInputSwapInfos(
        address tokenIn,
        address tokenOut,
        uint256 amountToSwap,
        uint160 minimumSqrtPrice
    ) external returns (SwapInfo[] memory swapInfos) {
        swapInfos = new SwapInfo[](feeTiers.length);

        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = IUniswapV3Factory(FACTORY).getPool(
                tokenIn,
                tokenOut,
                feeTiers[i]
            );
            uint128 liquidity = 0;
            bool sufficientLiquidity = false;

            if (pool != address(0)) {
                liquidity = IUniswapV3Pool(pool).liquidity();
                (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool)
                    .slot0();

                address token0 = IUniswapV3Pool(pool).token0();

                if (tokenIn == token0) {
                    uint256 reserve0 = (liquidity * uint256(sqrtPriceX96)) >>
                        96;
                    sufficientLiquidity = reserve0 >= amountToSwap;
                } else {
                    uint256 reserve1 = liquidity <<
                        (96 / uint256(sqrtPriceX96));
                    sufficientLiquidity = reserve1 >= amountToSwap;
                }

                try
                    IQuoterV2(QUOTER).quoteExactInputSingle(
                        IQuoterV2.QuoteExactInputSingleParams({
                            tokenIn: tokenIn,
                            tokenOut: tokenOut,
                            amountIn: amountToSwap,
                            fee: feeTiers[i],
                            sqrtPriceLimitX96: minimumSqrtPrice
                        })
                    )
                returns (
                    uint256 amountOut,
                    uint160 sqrtRatioX96,
                    uint32 initializedTicksCrossed,
                    uint256 gasEstimate
                ) {
                    swapInfos[i] = SwapInfo({
                        pool: pool,
                        feeTier: feeTiers[i],
                        amountOut: amountOut,
                        sqrtRatioX96: sqrtRatioX96,
                        initializedTicksCrossed: initializedTicksCrossed,
                        gasEstimate: gasEstimate,
                        liquidity: IUniswapV3Pool(pool).liquidity(),
                        sufficientLiquidity: sufficientLiquidity
                    });
                } catch {
                    continue;
                }
            }
        }
    }
}
