// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../common/ImmutableOwnable.sol";
import "../common/NonReentrant.sol";

import "./interfaces/IPriceOracle.sol";
import "./utils/OraclePoolsList.sol";

/***
 * @title ZkpPriceOracle
 * @notice It stores Uniswap V3 pool addresses and use them as price oracle to return FeeToken price
 * in terms of ZKP.
 ***/
contract ZkpPriceOracle is ImmutableOwnable, OraclePoolsList {
    // solhint-disable var-name-mixedcase

    // Address of the $ZKP token contract
    address private immutable ZKP_TOKEN;

    /// @notice Address of the priceOracle contract
    IPriceOracle public PriceOracle;

    // solhint-enable var-name-mixedcase

    uint256 public twapPeriod;

    event PriceOracleUpdated(address priceOracle);
    event TwapPeriodUpdated(uint256 newtwapPeriod);

    constructor(
        address _owner,
        address zkpToken,
        address priceOracle
    ) ImmutableOwnable(_owner) {
        require(
            zkpToken != address(0) && priceOracle != address(0),
            "ZPO: Zero address"
        );

        ZKP_TOKEN = zkpToken;
        PriceOracle = IPriceOracle(priceOracle);
    }

    /* ========== GETTER FUNCTIONS ========== */

    function getFeeTokenAmountOut(
        address feeToken,
        uint256 zkpTokenAmountIn
    ) external view returns (uint256 feeTokenAmountOut) {
        address pool = _getOraclePoolOrRevert(ZKP_TOKEN, feeToken);

        feeTokenAmountOut = PriceOracle.quoteOrRevert(
            uint128(zkpTokenAmountIn),
            ZKP_TOKEN,
            feeToken,
            pool,
            uint32(twapPeriod)
        );
    }

    function getOraclePoolForZkpToken(
        address feeToken
    ) public view returns (address) {
        return _getOraclePoolOrRevert(ZKP_TOKEN, feeToken);
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function addOraclePoolForZkpToken(
        address feeToken,
        address pool
    ) external onlyOwner {
        _addOraclePool(ZKP_TOKEN, feeToken, pool);
    }

    function removeOraclePoolForZkpToken(address feeToken) external onlyOwner {
        _removeOraclePool(ZKP_TOKEN, feeToken);
    }

    function updatePriceOracle(address priceOracle) external onlyOwner {
        require(priceOracle != address(0), "ZPO: Zero address");
        PriceOracle = IPriceOracle(priceOracle);

        emit PriceOracleUpdated(priceOracle);
    }

    function updateTwap(uint32 newTwapPeriod) external onlyOwner {
        require(newTwapPeriod > 0, "ZPO: Zero period");

        twapPeriod = uint256(newTwapPeriod);

        emit TwapPeriodUpdated(newTwapPeriod);
    }
}
