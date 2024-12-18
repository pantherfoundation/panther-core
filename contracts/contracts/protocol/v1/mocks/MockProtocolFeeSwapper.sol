// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "../feeMaster/ProtocolFeeSwapper.sol";

contract MockProtocolFeeSwapper is ProtocolFeeSwapper {
    constructor(address wethToken) UniswapV3Handler(wethToken) {}

    function trySwapProtoclFeesToNativeAndZkp(
        address zkpToken,
        address sellToken,
        uint256 sellAmount,
        uint256 nativeTokenReserves,
        uint256 nativeTokenReservesTarget
    )
        external
        returns (
            uint256 newNativeTokenReserves,
            uint256 outputWNative,
            uint256 outputZkpToken
        )
    {
        return
            _trySwapProtoclFeesToNativeAndZkp(
                zkpToken,
                sellToken,
                sellAmount,
                nativeTokenReserves,
                nativeTokenReservesTarget
            );
    }

    function addPool(address _pool, address _tokenA, address _tokenB) public {
        _updatePool(_pool, _tokenA, _tokenB, true);
    }

    function updateTwapPeriod(uint32 _twapPeriod) public {
        _updateTwapPeriod(_twapPeriod);
    }
}
