// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./UniswapV3Handler.sol";
import "./UniswapPoolsList.sol";
import { Pool } from "./Types.sol";

abstract contract ProtocolFeeSwapper is UniswapV3Handler, UniswapPoolsList {
    event ProtocolFeeSwapped(
        address sellToken,
        uint256 sellAmount,
        uint256 receivedNative,
        uint256 receivedZkp
    );

    function _trySwapProtoclFeesToNativeAndZkp(
        address zkpToken,
        address sellToken,
        uint256 sellAmount,
        uint256 nativeTokenReserves,
        uint256 nativeTokenReservesTarget
    )
        internal
        returns (
            uint256 newNativeTokenReserves,
            uint256 outputWNative,
            uint256 outputZkpToken
        )
    {
        // Converting sellToken for weth
        outputWNative = _convertTokenToNative(sellToken, sellAmount);

        assert(outputWNative > 0);

        newNativeTokenReserves = nativeTokenReserves + outputWNative;

        if (newNativeTokenReserves > nativeTokenReservesTarget) {
            // Getting the excess amount of Native tokens
            uint256 excessNative = newNativeTokenReserves -
                nativeTokenReservesTarget;

            // Converting Native to ZKP
            outputZkpToken = _convertNativeToZkp(zkpToken, excessNative);

            newNativeTokenReserves = nativeTokenReservesTarget;
        }

        // converting weth to Native
        uint256 wNativeBalance = TransferHelper.safeBalanceOf(
            WETH,
            address(this)
        );

        convertWNativeToNative(wNativeBalance);

        // emit selltoken, selltokenAmount, zkpConverted, nativeConverted
        emit ProtocolFeeSwapped(
            sellToken,
            sellAmount,
            outputWNative,
            outputZkpToken
        );
    }

    function _convertTokenToNative(
        address _token,
        uint256 _swapAmount
    ) private returns (uint256 receivedNative) {
        if (_token == WETH) {
            // skip the swap, if the sell token is wEth
            receivedNative = _swapAmount;
            return receivedNative;
        }

        // getting pool address
        Pool memory pool = getEnabledPoolOrRevert(WETH, _token);

        // Executing the flash swap and receive Natives
        receivedNative = _flashSwap(pool, _token, WETH, _swapAmount);
    }

    function _convertNativeToZkp(
        address _zkpToken,
        uint256 _swapAmount
    ) private returns (uint256 receivedZkp) {
        // getting pool address
        Pool memory pool = getEnabledPoolOrRevert(WETH, _zkpToken);

        // Executing the flash swap and receive ZKPs
        receivedZkp = _flashSwap(pool, WETH, _zkpToken, _swapAmount);
    }

    function _decodeDataAndVerifySender(
        bytes calldata data
    )
        internal
        view
        override
        returns (address poolAddress, address token0, address token1)
    {
        (poolAddress, token0, token1) = abi.decode(
            data,
            (address, address, address)
        );

        Pool memory pool = getEnabledPoolOrRevert(token0, token1);

        require(
            pool._address == poolAddress,
            "uniswapV3SwapCallback::Invalid pool address"
        );
        require(
            msg.sender == poolAddress,
            "uniswapV3SwapCallback::Invalid sender"
        );
    }
}
