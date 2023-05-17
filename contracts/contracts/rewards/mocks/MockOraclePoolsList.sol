// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../utils/OraclePoolsList.sol";

contract MockOraclePoolsList is OraclePoolsList {
    function internalAddOraclePool(
        address tokenA,
        address tokenB,
        address pool
    ) external {
        _addOraclePool(tokenA, tokenB, pool);
    }

    function internalRemoveOraclePool(address tokenA, address tokenB) external {
        _removeOraclePool(tokenA, tokenB);
    }

    function internalGetOraclePoolOrRevert(address tokenA, address tokenB)
        external
        view
        returns (address pool)
    {
        return _getOraclePoolOrRevert(tokenA, tokenB);
    }
}
