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

    uint256 public twapPeriod;

    event TwapPeriodUpdated(uint256 twapPeriod);

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
        if (baseToken == NATIVE_TOKEN) {
            baseToken = WETH;
        }
        if (quoteToken == NATIVE_TOKEN) {
            quoteToken = WETH;
        }

        return
            pool.getQuoteAmount(baseToken, quoteToken, baseAmount, twapPeriod);
    }

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

    function _updateTwapPeriod(uint256 _twapPeriod) internal {
        require(_twapPeriod > 0, "zero twap");
        twapPeriod = _twapPeriod;

        emit TwapPeriodUpdated(twapPeriod);
    }

    function _flashSwap(
        address pool,
        address inputToken,
        address outputToken,
        uint256 swapAmount
    ) internal returns (uint256 outputAmount) {
        // TODO: maybe storing WETH9 as storage

        if (inputToken == NATIVE_TOKEN) {
            inputToken = WETH;
            IWETH(inputToken).deposit{ value: uint256(swapAmount) }();
        }

        if (outputToken == NATIVE_TOKEN) {
            outputToken = WETH;
        }

        uint256 exchangeRate = getQuoteAmount(
            pool,
            inputToken,
            outputToken,
            swapAmount
        );

        uint160 sqrtPriceLimitX96 = uint160(Math.sqrt(exchangeRate << 192));

        outputAmount = pool.swapExactInput(
            inputToken,
            outputToken,
            swapAmount,
            sqrtPriceLimitX96
        );
    }

    receive() external payable {}
}
