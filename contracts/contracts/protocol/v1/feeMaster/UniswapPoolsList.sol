// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./PoolKey.sol";

abstract contract UniswapPoolsList {
    struct Pool {
        address _address;
        bool _enabled;
    }

    mapping(bytes32 => Pool) public pools;

    function getEnabledPoolAddress(
        address tokenA,
        address tokenB
    ) public view returns (address) {
        bytes32 key = PoolKey.getKey(tokenA, tokenB);
        Pool memory pool = pools[key];

        require(pool._enabled, "pool is disabled");
        return pool._address;
    }

    function _updatePool(
        address _pool,
        address _tokenA,
        address _tokenB,
        bool _enabled
    ) internal returns (bytes32 key) {
        require(_pool != address(0), "addPool: zero address");
        key = PoolKey.getKey(_tokenA, _tokenB);

        pools[key] = Pool({ _address: _pool, _enabled: _enabled });
    }
}
