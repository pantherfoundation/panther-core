// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../errMsgs/OraclePoolsListErrMsgs.sol";

/**
 * @title OraclePoolsList
 * @notice It maintains a list of pools which can be used as price oracle.
 */
abstract contract OraclePoolsList {
    mapping(bytes32 => address) private oraclePools;

    event OraclePoolsUpdated(address tokenA, address tokenB, address pool);

    function _getPoolKey(address tokenA, address tokenB)
        private
        pure
        returns (bytes32)
    {
        return
            bytes32(uint256(uint160(tokenA)) << 96) &
            bytes32(uint256(uint160(tokenB)) << 96);
    }

    function _addOraclePool(
        address tokenA,
        address tokenB,
        address pool
    ) internal {
        require(
            tokenA != address(0) && tokenB != address(0) && pool != address(0),
            ERR_ZERO_ADDRESS
        );

        bytes32 poolKey = _getPoolKey(tokenA, tokenB);
        require(oraclePools[poolKey] == address(0), ERR_POOL_ALREADY_EXISTS);

        oraclePools[poolKey] = pool;

        emit OraclePoolsUpdated(tokenA, tokenB, pool);
    }

    function _removeOraclePool(address tokenA, address tokenB) internal {
        require(tokenA != address(0) && tokenB != address(0), ERR_ZERO_ADDRESS);

        bytes32 poolKey = _getPoolKey(tokenA, tokenB);
        require(oraclePools[poolKey] != address(0), ERR_POOL_NOT_EXISTS);

        oraclePools[poolKey] = address(0);

        emit OraclePoolsUpdated(tokenA, tokenB, address(0));
    }

    function _getOraclePoolOrRevert(address tokenA, address tokenB)
        internal
        view
        returns (address pool)
    {
        pool = oraclePools[_getPoolKey(tokenA, tokenB)];
        require(pool != address(0), ERR_POOL_NOT_EXISTS);
    }
}
