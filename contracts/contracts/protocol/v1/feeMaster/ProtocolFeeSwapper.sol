// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./UniswapV3Handler.sol";
import "./UniswapPoolsList.sol";
import { NATIVE_TOKEN } from "../../../common/Constants.sol";

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
        returns (uint256 newNativeTokenReserves, uint256 newProtocolFeeInZkp)
    {
        // Converting sellToken for weth
        uint256 receivedWNative = _convertTokenToNative(sellToken, sellAmount);

        assert(receivedWNative > 0);

        newNativeTokenReserves = nativeTokenReserves + receivedWNative;

        if (newNativeTokenReserves > nativeTokenReservesTarget) {
            // Getting the excess amount of Native tokens
            uint256 excessNative = newNativeTokenReserves -
                nativeTokenReservesTarget;

            // Converting Native to ZKP
            newProtocolFeeInZkp = _convertNativeToZkp(zkpToken, excessNative);

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
            receivedWNative,
            newProtocolFeeInZkp
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
        address pool = getEnabledPoolAddress(NATIVE_TOKEN, _token);

        // Executing the flash swap and receive Natives
        receivedNative = _flashSwap(pool, _token, NATIVE_TOKEN, _swapAmount);
    }

    function _convertNativeToZkp(
        address _zkpToken,
        uint256 _swapAmount
    ) private returns (uint256 receivedZkp) {
        // getting pool address
        address pool = getEnabledPoolAddress(NATIVE_TOKEN, _zkpToken);

        // Executing the flash swap and receive ZKPs
        receivedZkp = _flashSwap(pool, NATIVE_TOKEN, _zkpToken, _swapAmount);
    }
}
