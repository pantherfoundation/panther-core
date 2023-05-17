// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IPriceOracle {
    function quoteOrRevert(
        uint128 baseAmount,
        address baseToken,
        address quoteToken,
        address pool,
        uint32 period
    ) external view returns (uint256 quoteAmount);
}
