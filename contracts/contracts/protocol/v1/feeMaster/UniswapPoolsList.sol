// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./PoolKey.sol";

abstract contract UniswapPoolsList {
    struct Pool {
        address _address;
        bool _enabled;
    }

    mapping(bytes4 => Pool) public pools;

    function getEnabledPoolAddress(
        address tokenA,
        address tokenB
    ) public view returns (address) {
        bytes4 key = PoolKey.getKey(tokenA, tokenB);
        Pool memory pool = pools[key];

        require(pool._enabled, "pool is disaled");
        return pool._address;
    }

    function _addPool(
        address _pool,
        address _tokenA,
        address _tokenB
    ) internal {
        bytes4 key = PoolKey.getKey(_tokenA, _tokenB);
        pools[key] = Pool({ _address: _pool, _enabled: true });
    }

    function _updatePool(
        address _tokenA,
        address _tokenB,
        address _address,
        bool _enabled
    ) internal {
        bytes4 key = PoolKey.getKey(_tokenA, _tokenB);
        Pool memory pool = pools[key];

        require(pool._address != address(0), "Pool not found");

        pools[key] = Pool({ _address: _address, _enabled: _enabled });
    }
}
