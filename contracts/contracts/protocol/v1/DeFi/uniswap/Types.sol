// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

struct SwapCallbackData {
    bytes path;
    address payer;
}

struct SwapInfo {
    address pool;
    uint16 feeTier;
    uint256 amountOut;
    uint160 sqrtRatioX96;
    uint32 initializedTicksCrossed;
    uint256 gasEstimate;
    uint128 liquidity;
    bool sufficientLiquidity;
}

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}
