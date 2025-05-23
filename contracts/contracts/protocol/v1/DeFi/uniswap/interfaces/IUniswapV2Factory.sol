// SPDX-License-Identifier: MIT
// solhint-disable compiler-version
pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}
