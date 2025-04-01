// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./PoolKey.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3Pool.sol";
import { Pool } from "./Types.sol";

abstract contract UniswapPoolsList {
    mapping(bytes32 => Pool) public pools;

    function getEnabledPoolOrRevert(
        address tokenA,
        address tokenB
    ) public view returns (Pool memory pool) {
        bytes32 key = PoolKey.getKey(tokenA, tokenB);
        pool = pools[key];

        require(pool._enabled, "pool is disabled");
    }

    function _updatePool(
        address pool,
        address token0,
        address token1,
        bool enabled
    ) internal returns (bytes32 key) {
        require(pool != address(0), "addPool: zero address");

        address _token0 = IUniswapV3Pool(pool).token0();
        address _token1 = IUniswapV3Pool(pool).token1();

        require(token0 == _token0, "invalid token0");
        require(token1 == _token1, "invalid token1");

        key = PoolKey.getKey(token0, token1);

        pools[key] = Pool({
            _address: pool,
            _token0: token0,
            _token1: token1,
            _enabled: enabled
        });
    }
}
