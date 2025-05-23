// SPDX-License-Identifier: MIT
// solhint-disable compiler-version
pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
