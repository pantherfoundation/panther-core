// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../DeFi/uniswap/interfaces/IUniswapV3SwapCallback.sol";
import "../DeFi/UniswapV3PriceFeed.sol";
import "../DeFi/UniswapV3FlashSwap.sol";

import "../../../common/interfaces/IWETH.sol";
import "../../../common/TransferHelper.sol";
import "../../../common/Math.sol";

import { Pool } from "./Types.sol";

abstract contract UniswapV3Handler is IUniswapV3SwapCallback {
    using UniswapV3PriceFeed for address;
    using UniswapV3FlashSwap for address;
    using TransferHelper for address;

    address public immutable WETH;

    uint32 public twapPeriod;

    constructor(address weth) {
        require(weth != address(0), "zero address");
        WETH = weth;
    }

    function getTrustedPoolQuoteAmount(
        Pool memory pool,
        address baseToken,
        address quoteToken,
        uint256 baseAmount
    ) public view returns (uint256) {
        return
            pool._address.getTrustedPoolQuoteAmount(
                pool._token0,
                pool._token1,
                baseToken,
                quoteToken,
                baseAmount,
                twapPeriod
            );
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        (
            address pool,
            address token0,
            address token1
        ) = _decodeDataAndVerifySender(data);

        if (amount0Delta > 0) token0.safeTransfer(pool, uint256(amount0Delta));
        if (amount1Delta > 0) token1.safeTransfer(pool, uint256(amount1Delta));
    }

    function _updateTwapPeriod(uint32 _twapPeriod) internal {
        require(_twapPeriod > 0, "zero twap");
        twapPeriod = _twapPeriod;
    }

    function convertNativeToWNative(uint256 nativeAmount) internal {
        WETH.safeTransferETH(nativeAmount);
    }

    function convertWNativeToNative(uint256 wNativeAmount) internal {
        IWETH(WETH).withdraw(wNativeAmount);
    }

    function getSqrtPriceLimitX96(
        Pool memory pool,
        address inputToken,
        address outputToken,
        uint256 slippageTolerance // e.g., 100 = 1%, 10 = 0.1%
    ) internal view returns (uint160 sqrtPriceLimitX96) {
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(pool._address);

        // Determine tokens in the pool
        address token0 = pool._token0;
        address token1 = pool._token1;

        // Determine swap direction
        bool zeroForOne = inputToken == token0 && outputToken == token1;

        // Validate tokens are in the pool
        require(
            (inputToken == token0 || inputToken == token1) &&
                (outputToken == token0 || outputToken == token1),
            "Invalid tokens for pool"
        );

        // Get current price from slot0
        (uint160 currentSqrtPriceX96, , , , , , ) = uniswapPool.slot0();

        if (zeroForOne) {
            // Swapping token0 for token1 - set a lower price limit
            // Calculate the lower bound based on slippage tolerance
            sqrtPriceLimitX96 = uint160(
                (currentSqrtPriceX96 * (10000 - slippageTolerance)) / 10000
            );

            // Ensure the limit is not below the minimum possible sqrt price
            sqrtPriceLimitX96 = sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
                ? TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96;
        } else {
            // Swapping token1 for token0 - set an upper price limit
            // Calculate the upper bound based on slippage tolerance
            sqrtPriceLimitX96 = uint160(
                (currentSqrtPriceX96 * (10000 + slippageTolerance)) / 10000
            );

            // Ensure the limit is not above the maximum possible sqrt price
            sqrtPriceLimitX96 = sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
                ? TickMath.MAX_SQRT_RATIO
                : sqrtPriceLimitX96;
        }
    }

    function _flashSwap(
        Pool memory pool,
        address inputToken,
        address outputToken,
        uint256 swapAmount
    ) internal returns (uint256 outputAmount) {
        outputAmount = pool._address.swapExactInput(
            inputToken,
            outputToken,
            swapAmount,
            getSqrtPriceLimitX96(pool, inputToken, outputToken, 500)
        );
    }

    function _decodeDataAndVerifySender(
        bytes calldata data
    )
        internal
        view
        virtual
        returns (address pool, address token0, address token1);

    /**
     * @dev Reverts any direct ETH transfers to the FeeMaster implementation contract.
     * Since this contract is meant to be used behind a proxy, direct ETH transfers
     * to the implementation contract should be prevented to avoid locking funds.
     * ETH transfers should go through the proxy contract instead.
     */
    receive() external payable virtual {
        revert("Direct ETH transfers to implementation not allowed");
    }
}
