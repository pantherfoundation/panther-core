// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
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
    ) internal pure returns (bytes4 key) {
        (address _tokenA, address _tokenB) = sortTokens(tokenA, tokenB);
        return bytes4(keccak256(abi.encodePacked(_tokenA, _tokenB)));
    }
}
