// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./uniswap/interfaces/IUniswapV3Pool.sol";
import "../../../common/interfaces/IWETH.sol";

import "./uniswap/libraries/FixedPoint96.sol";
import "./uniswap/libraries/FullMath.sol";
import "./uniswap/libraries/TickMath.sol";

import "../feeMaster/PoolKey.sol";
import "../../../common/TransferHelper.sol";

library UniswapV3FlashSwap {
    using TransferHelper for address;

    function convertNativeToWNative(
        address wNative,
        uint256 nativeAmount
    ) internal {
        wNative.safeTransferETH(nativeAmount);
    }

    function convertWNativeToNative(
        address wNative,
        uint256 wNativeAmount
    ) internal {
        IWETH(wNative).withdraw(wNativeAmount);
    }

    function swapExactInput(
        address pool,
        address inputToken,
        address outputToken,
        uint256 swapAmount,
        uint160 sqrtPriceLimitX96
    ) internal returns (uint256 outputAmount) {
        (address tokenA, address tokenB) = PoolKey.sortTokens(
            inputToken,
            outputToken
        );
        bytes memory data = abi.encode(pool, tokenA, tokenB);

        bool zeroForOne = inputToken == tokenA;

        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne, // The direction of the swap, true for tokenA to tokenB
            int256(swapAmount), //  positive means swap as exact input
            sqrtPriceLimitX96 == 0
                ? (
                    zeroForOne
                        ? TickMath.MIN_SQRT_RATIO + 1
                        : TickMath.MAX_SQRT_RATIO - 1
                )
                : sqrtPriceLimitX96,
            data
        );

        outputAmount = zeroForOne ? uint256(-amount1) : uint256(-amount0);
    }

    /**
     !! The folowing function shall be implemented in the caller contract:

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
     */
}
