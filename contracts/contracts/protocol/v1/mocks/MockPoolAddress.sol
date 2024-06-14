// SPDX-License-Identifier: GPL-2.0-or-later
// solhint-disable compiler-version
// solhint-disable reason-string
pragma solidity >=0.5.0;

import "./MockUniswapV3Pool.sol";

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library MockPoolAddress {
    /// @notice  POOL_INIT_CODE_HASH = keccak256(type(MockUniswapV3Pool).creationCode);
    bytes32 public constant POOL_INIT_CODE_HASH =
        hex"2d1e7fb25e8434425f1e5d59e586934e690670c68b61b94f786472ef046f2d74";

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({ token0: tokenA, token1: tokenB, fee: fee });
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return _pool The contract address of the V3 pool
    function computeAddress(
        address factory,
        PoolKey memory key
    ) internal view returns (address _pool) {
        require(key.token0 < key.token1, "token0 > token1");
        bytes32 poolHash = keccak256(
            abi.encodePacked(
                hex"ff",
                factory,
                keccak256(abi.encode(key.token0, key.token1, key.fee)),
                POOL_INIT_CODE_HASH
            )
        );
        bytes20 addressBytes = bytes20(poolHash << (256 - 160));
        _pool = address(uint160(addressBytes));
    }
}
