// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../DeFi/uniswap/interfaces/IUniswapV3SwapCallback.sol";
import "../DeFi/UniswapV3PriceFeed.sol";
import "../DeFi/UniswapV3FlashSwap.sol";

import "../../../common/interfaces/IWETH.sol";
import "../../../common/TransferHelper.sol";
import "../../../common/Math.sol";

import { NATIVE_TOKEN } from "../../../common/Constants.sol";

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

    function getQuoteAmount(
        address pool,
        address baseToken,
        address quoteToken,
        uint256 baseAmount
    ) public view returns (uint256) {
        return
            pool.getQuoteAmount(baseToken, quoteToken, baseAmount, twapPeriod);
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

    // This function calculates sqrtPriceLimitX96 based on TWAP price
    function getSqrtPriceLimitX96(
        uint256 twapPrice
    ) internal pure returns (uint160) {
        // Step 1: Take the square root of the TWAP price
        uint256 sqrtPrice = sqrt(twapPrice);

        // Step 2: Convert it to the Q96 format (scaled by 2^96)
        uint160 sqrtPriceLimitX96 = uint160((sqrtPrice << 96) / (1 << 48));

        return sqrtPriceLimitX96;
    }

    // Internal pure function to calculate square root of a given value
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _mapNativeToWrappedToken(
        address inputToken,
        address outputToken
    ) internal view returns (address, address) {
        if (inputToken == NATIVE_TOKEN) {
            inputToken = WETH;
        }
        if (outputToken == NATIVE_TOKEN) {
            outputToken = WETH;
        }

        return (inputToken, outputToken);
    }

    function _mapWrappedToNativeToken(
        address inputToken,
        address outputToken
    ) internal view returns (address, address) {
        if (inputToken == WETH) {
            inputToken = NATIVE_TOKEN;
        }
        if (outputToken == WETH) {
            outputToken = NATIVE_TOKEN;
        }

        return (inputToken, outputToken);
    }

    function _flashSwap(
        address pool,
        address inputToken,
        address outputToken,
        uint256 swapAmount
    ) internal returns (uint256 outputAmount) {
        (inputToken, outputToken) = _mapNativeToWrappedToken(
            inputToken,
            outputToken
        );

        uint256 exchangeRate = getQuoteAmount(
            pool,
            inputToken,
            outputToken,
            swapAmount
        );

        outputAmount = pool.swapExactInput(
            inputToken,
            outputToken,
            swapAmount,
            getSqrtPriceLimitX96(exchangeRate)
        );
    }

    function _decodeDataAndVerifySender(
        bytes calldata data
    )
        internal
        view
        virtual
        returns (address pool, address token0, address token1);

    receive() external payable {}
}
