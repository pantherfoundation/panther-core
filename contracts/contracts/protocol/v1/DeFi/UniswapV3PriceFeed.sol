// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./uniswap/interfaces/IUniswapV3Pool.sol";
import "./uniswap/libraries/FixedPoint96.sol";
import "./uniswap/libraries/FullMath.sol";
import "./uniswap/libraries/TickMath.sol";

library UniswapV3PriceFeed {
    function getQuoteAmount(
        address pool,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint32 secondsAgo //e.g., 60 for 1 minute TWAP
    ) internal view returns (uint256 quoteAmount) {
        // Interface the Uniswap pool
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(pool);

        // Retrieve actual token0 and token1 addresses from the pool
        address token0 = uniswapPool.token0();
        address token1 = uniswapPool.token1();

        // Ensure that the input and output tokens are part of the pool
        require(
            (inputToken == token0 && outputToken == token1) ||
                (inputToken == token1 && outputToken == token0),
            "Tokens not in the pool"
        );

        // Get the current tick (price) using oracle
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo; // TWAP period
        secondsAgos[1] = 0; // The current block timestamp

        (int56[] memory tickCumulatives, ) = uniswapPool.observe(secondsAgos);

        // Calculate the time-weighted average tick
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int56 timeElapsed = int56(uint56(secondsAgo)); // The time difference

        // Calculate average tick
        int24 averageTick = int24(tickCumulativesDelta / timeElapsed);

        // Adjust for negative tickCumulativesDelta and remainder issue
        if (
            tickCumulativesDelta < 0 && tickCumulativesDelta % timeElapsed != 0
        ) {
            averageTick--;
        }

        require(
            averageTick >= TickMath.MIN_TICK &&
                averageTick <= TickMath.MAX_TICK,
            "Invalid tick range"
        );

        // Convert the average tick to a price (sqrtPriceX96)
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(averageTick);

        // Calculate the price as a Q96 value
        uint256 priceX96 = FullMath.mulDiv(
            sqrtPriceX96,
            sqrtPriceX96,
            FixedPoint96.Q96
        );

        // Determine if inputToken is token0 or token1 and calculate accordingly
        if (inputToken == token0) {
            // Input token is token0, output token is token1
            quoteAmount = FullMath.mulDiv(
                inputAmount,
                priceX96,
                FixedPoint96.Q96
            );
        } else {
            // Input token is token1, output token is token0
            quoteAmount = FullMath.mulDiv(
                inputAmount,
                FixedPoint96.Q96,
                priceX96
            );
        }

        return quoteAmount;
    }
}
