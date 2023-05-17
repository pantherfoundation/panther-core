// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IZkpPriceOracle {
    function getFeeTokenAmountOut(address feeToken, uint256 zkpTokenAmountIn)
        external
        returns (uint256 feeTokenAmountOut);
}
