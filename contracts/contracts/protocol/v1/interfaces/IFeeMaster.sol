// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./IFeeAccountant.sol";
import { FeeParams } from "../feeMaster/Types.sol";

interface IFeeMaster is IFeeAccountant {
    /**
     * @dev Emitted when native token reserve target is updated.
     * @param nativeTokenReserveTarget The new target amount of native token reserve.
     */
    event NativeTokenReserveTargetUpdated(uint256 nativeTokenReserveTarget);

    /**
     * @dev Emitted Zkp donations is updated.
     * @param zkpTokenDonation The added donation amount
     */
    event ZkpTokenDonationsUpdated(uint256 zkpTokenDonation);

    /**
     * @dev Emitted when native token reserve is updated.
     * @param nativeTokenReserve The new amount of native token reserve.
     */
    event NativeTokenReserveUpdated(uint256 nativeTokenReserve);

    /**
     * @dev Emitted when donations are updated.
     * @param txType The transaction type for which donation is updated.
     * @param donation The new donation amount.
     */
    event DonationsUpdated(uint16 txType, uint256 donation);

    /**
     * @dev Emitted when fee params are updated
     * @param feeParams params for calculating fees
     */
    event FeeParamsUpdated(FeeParams feeParams);

    /**
     * @dev Emitted zkp distribution params updated
     * @param treasuryLockPercentage the percentgage of fee that needs to be sent to
     * the treasury, after deduction of miner premium rewards
     * @param minRewardableZkpAmount min amount of distributed zkps which generates prp rewards
     */
    event ProtocolZkpFeeDistributionParamsUpdated(
        uint16 treasuryLockPercentage,
        uint96 minRewardableZkpAmount
    );

    /**
     * @dev Emitted when zkps are distributed
     * @param totalAmount  total distributed amout of zkps
     * @param minerPremiumRewards amount of zkps to cover miner premium rewards
     */
    event ZkpsDistributed(uint256 totalAmount, uint256 minerPremiumRewards);

    /**
     * @dev Emitted when twap updated
     * @param twapPeriod period for time weighted avg price
     */
    event TwapPeriodUpdated(uint256 twapPeriod);

    /**
     * @dev Emitted when pool address is updated
     * @param pool address of uniswap v3 pool
     * @param enabled true/false for enabling/desabling pool
     */
    event PoolUpdated(address pool, bool enabled);

    /**
     * @dev Emitted when protocol pays the collected fees
     * @param receiver address of the fee receiver
     * @param token address of the fee token
     * @param amount the amount that is sent
     */
    event PayOff(address receiver, address token, uint256 amount);

    /**
     * @dev Gets the rate of native token in terms of zk-proof token.
     * @param nativeAmount The amount of native token.
     * @return The rate of native token in zk-proof token.
     */
    function getNativeRateInZkp(
        uint256 nativeAmount
    ) external view returns (uint256);

    /**
     * @dev Gets the rate of zk-proof token in terms of native token.
     * @param zkpAmount The amount of zk-proof token.
     * @return The rate of zk-proof token in native token.
     */
    function getZkpRateInNative(
        uint256 zkpAmount
    ) external view returns (uint256);

    /**
     * @dev Updates the target amount of native token reserve.
     * @param _nativeTokenReserveTarget The new target amount of native token reserve.
     */
    function updateNativeTokenReserveTarget(
        uint256 _nativeTokenReserveTarget
    ) external;

    /**
     * @dev Increases the zk-proof token donation reserve.
     * @param _zkpTokenDonation The amount of zk-proof token to be added to the donation reserve.
     */
    function increaseZkpTokenDonations(uint256 _zkpTokenDonation) external;

    /**
     * @dev Increases the native token reserve.
     */
    function increaseNativeTokenReserves() external payable;

    /**
     * @dev Updates the donation amount for a specific transaction type.
     * @param txTypes The transaction types for which donation amount is updated.
     * @param donateAmounts The exact amounts that must be donated.
     */
    function updateDonations(
        uint16[] calldata txTypes,
        uint256[] calldata donateAmounts
    ) external;

    /**
     * @dev Adds a new pool.
     * @param _pool The address of the pool contract.
     * @param _tokenA Address of the token A.
     * @param _tokenB Address of the token B.
     */
    function addPool(address _pool, address _tokenA, address _tokenB) external;

    /**
     * @dev Updates an existing pool.
     * @param _pool The address of the pool contract.
     * @param _tokenA Address of the token A.
     * @param _tokenB Address of the token B.
     * @param _enabled Whether the pool is enabled or not.
     */
    function updatePool(
        address _pool,
        address _tokenA,
        address _tokenB,
        bool _enabled
    ) external;

    /**
     * @dev Rebalances the debt.
     * @param sellToken The token to be sold.
     */
    function rebalanceDebt(bytes32 secretHash, address sellToken) external;

    /**
     * @dev Distributes the protocol fees in zk-proof token.
     */
    function distributeProtocolZkpFees(bytes32 secretHash) external;

    /**
     * @dev Accounts for the fees incurred in a transaction.
     * @param feeData Fee data containing transaction type and fee amounts.
     * @return chargedFeesPerTx The charged fees for the transaction.
     */
    function accountFees(
        FeeData calldata feeData
    ) external returns (ChargedFeesPerTx memory chargedFeesPerTx);

    /**
     * @dev Accounts for the fees incurred in a transaction involving assets.
     * @param feeData Fee data containing transaction type and fee amounts.
     * @param assetData Asset data containing information about the assets involved
     * in the transaction.
     * @return chargedFeesPerTx The charged fees for the transaction.
     */
    function accountFees(
        FeeData calldata feeData,
        AssetData calldata assetData
    ) external returns (ChargedFeesPerTx memory chargedFeesPerTx);
}
