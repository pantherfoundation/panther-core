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
        returns (uint256 newNativeTokenReserves, uint256 newProtocolFeeInZkp)
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
        _addPool(_pool, _tokenA, _tokenB);
    }

    function updateTwapPeriod(uint256 _twapPeriod) public {
        _updateTwapPeriod(_twapPeriod);
    }
}
