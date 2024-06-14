// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./MockUniswapV3Pool.sol";
import "./MockPoolAddress.sol";

contract MockUniswapV3Factory {
    mapping(address => mapping(address => mapping(uint24 => address)))
        public getPool;

    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
    }

    Parameters public parameters;

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee
    ) internal returns (address pool) {
        parameters = Parameters({
            factory: factory,
            token0: token0,
            token1: token1,
            fee: fee
        });
        pool = address(
            new MockUniswapV3Pool{
                salt: keccak256(abi.encode(token0, token1, fee))
            }()
        );
        address pool1 = MockPoolAddress.computeAddress(
            factory,
            MockPoolAddress.getPoolKey(token0, token1, fee)
        );
        require(pool == pool1, "WRONG");
        delete parameters;
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool) {
        require(tokenA != tokenB, "same token");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "token0");
        require(getPool[token0][token1][fee] == address(0), "exists");

        pool = deploy(address(this), token0, token1, fee);
        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;
    }

    function setPoolAddress(
        address tokenA,
        address tokenB,
        uint24 fee,
        address newAddress
    ) external {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        getPool[token0][token1][fee] = newAddress;
        getPool[token1][token0][fee] = newAddress;
    }
}
