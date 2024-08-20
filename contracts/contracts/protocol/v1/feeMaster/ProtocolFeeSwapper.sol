// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./UniswapV3Handler.sol";
import "./UniswapPoolsList.sol";
import { NATIVE_TOKEN } from "../../../common/Constants.sol";

abstract contract ProtocolFeeSwapper is UniswapV3Handler, UniswapPoolsList {
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
        // Converting sellToken for Native
        uint256 receivedNative = _convertTokenToNative(sellToken, sellAmount);

        uint256 nativeBalance = address(this).balance;
        assert(nativeBalance >= receivedNative);

        newNativeTokenReserves = nativeTokenReserves + nativeBalance;

        if (newNativeTokenReserves > nativeTokenReservesTarget) {
            // Getting the excess amount of Native tokens
            uint256 excessNative = newNativeTokenReserves -
                nativeTokenReservesTarget;

            // Converting Native to ZKP
            newProtocolFeeInZkp = _convertNativeToZkp(zkpToken, excessNative);

            newNativeTokenReserves = nativeTokenReservesTarget;
        }
    }

    function _convertTokenToNative(
        address _token,
        uint256 _swapAmount
    ) private returns (uint256 receivedNative) {
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
