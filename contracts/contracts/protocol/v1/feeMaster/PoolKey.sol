// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

library PoolKey {
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address, address) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return (tokenA, tokenB);
    }

    function getKey(
        address tokenA,
        address tokenB
    ) internal pure returns (bytes32 key) {
        (address _tokenA, address _tokenB) = sortTokens(tokenA, tokenB);
        return keccak256(abi.encodePacked(_tokenA, _tokenB));
    }
}
