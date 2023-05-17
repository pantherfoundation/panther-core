// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
// solhint-disable-next-line compiler-version
pragma solidity >=0.7.6 <=0.8.16;

import "./uniswap/OracleLibrary.sol";

/**
 * @title PriceOracle
 * @notice It uses Uniswap v3 to get the time weighted average price
 */
contract PriceOracle {
    function quoteOrRevert(
        uint128 baseAmount,
        address baseToken,
        address quoteToken,
        address pool,
        uint32 period
    ) external view returns (uint256 quoteAmount) {
        require(
            baseToken != address(0) &&
                quoteToken != address(0) &&
                pool != address(0),
            "UPO:E1"
        );

        OracleLibrary.WeightedTickData memory _tickData;

        // Note: we should be sure the period is less than pool's oldest observation
        (_tickData.tick, ) = OracleLibrary.consult(pool, period);

        quoteAmount = OracleLibrary.getQuoteAtTick(
            _tickData.tick,
            baseAmount,
            baseToken,
            quoteToken
        );
    }
}
