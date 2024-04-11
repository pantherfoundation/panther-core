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
        uint256 twapPeriod
    ) internal view returns (uint256 quoteAmount) {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = uint32(twapPeriod); // from (before)
        secondsAgo[1] = 0; // to (now)

        // Get the historical tick data using the observe() function
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(
            secondsAgo
        );

        int24 tick = int24(
            (tickCumulatives[1] - tickCumulatives[0]) /
                int56(uint56(twapPeriod))
        );
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        if (sqrtPriceX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtPriceX96) * sqrtPriceX96;
            quoteAmount = inputToken < outputToken
                ? FullMath.mulDiv(ratioX192, inputAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, inputAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(
                sqrtPriceX96,
                sqrtPriceX96,
                1 << 64
            );
            quoteAmount = inputToken < outputToken
                ? FullMath.mulDiv(ratioX128, inputAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, inputAmount, ratioX128);
        }
    }
}
