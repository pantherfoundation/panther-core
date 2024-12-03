// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./ICachedNativeZkpTwap.sol";
import "./IFeeAccountant.sol";
import "./IPayOff.sol";
import { FeeParams } from "../feeMaster/Types.sol";

interface IFeeMaster is ICachedNativeZkpTwap, IFeeAccountant, IPayOff {
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
     * @dev Emitted when a paymaster's compensation is accounted.
     * @param paymasterDebtInZkp The portion of the compensation that remains as debt in ZKP tokens.
     * @param paymasterDebtInNative The portion of the compensation successfully converted to native tokens.
     */
    event PaymasterCompensationConverted(
        uint256 paymasterDebtInZkp,
        uint256 paymasterDebtInNative
    );

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
     * @param distributedAmount  total distributed amout of zkps
     */
    event ZkpsDistributed(uint256 distributedAmount);

    /**
     * @dev Emitted when twap updated
     * @param twapPeriod period for time weighted avg price
     */
    event TwapPeriodUpdated(uint256 twapPeriod);

    /**
     * @dev Emitted when pool address is updated
     * @param pool address of uniswap v3 pool
     * @param key the pool key to read the pool from `pools` mapping
     * @param enabled true/false for enabling/desabling pool
     */
    event PoolUpdated(address pool, bytes32 key, bool enabled);

    /**
     * @dev Updates the target amount of native token reserve.
     * @param _nativeTokenReserveTarget The new target amount of native token reserve.
     */
    function updateNativeTokenReserveTarget(
        uint256 _nativeTokenReserveTarget
    ) external;

    /**
     * @dev Increases the zkp token donation reserve.
     * @param _zkpTokenDonation The amount of zkp token to be added to the donation reserve.
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
     * @notice Updates or registers a Uniswap V3 pool for a specific token pair.
     * @dev This function allows the contract owner to add, update, or deactivate a Uniswap V3 pool
     *      used for swapping between a designated sell token and the native token. The native token
     *      is represented by the zero address (`address(0)`) within the `FeeMaster` contract, while
     *      Uniswap V3 interacts with its wrapped version (e.g., WETH). This distinction ensures seamless
     *      integration between `FeeMaster` and Uniswap V3 pools.
     * @param _pool The address of the Uniswap V3 pool contract to be added or updated.
     *             - Must be a valid Uniswap V3 pool address.
     *             - Represents the liquidity pool facilitating swaps between `tokenA` and `tokenB`.
     * @param _tokenA The address of the first token in the pair.
     *               - For native token, use `address(0)` to represent the native token.
     *               - Must be a valid ERC20 token address.
     * @param _tokenB The address of the second token in the pair.
     *               - For native token, use `address(0)` to represent the native token.
     *               - Must be a valid ERC20 token address distinct from `tokenA`.
     *
     * @param _enabled A boolean flag indicating the pool's status.
     *               - `true`: The pool is active and can be used for swapping.
     *               - `false`: The pool is inactive and will be excluded from swap operations.
     */
    function updatePool(
        address _pool,
        address _tokenA,
        address _tokenB,
        bool _enabled
    ) external;

    /**
     * @notice Rebalances the protocol debts by converting sell tokens to native tokens and ZKP.
     * @dev This function performs the following operations:
     *      1. Retrieves the total protocol debt in the specified sellToken.
     *      2. Updates the protocol's debt by reducing it by the sellTokenAmount.
     *      3. Adjusts the vault assets and updates the total FeeMaster debt in sellToken via the Panther Pool.
     *      4. Attempts to swap the sellTokenAmount to native tokens and ZKP, aiming to reach the target native token reserve.
     *      5. Updates the native token reserve based on the swap results.
     *      6. Adjusts the vault assets and updates the total FeeMaster debt in native tokens.
     *      7. If a new protocol fee in ZKP is generated, updates the protocol's debt in ZKP and adjusts the vault assets accordingly.
     *      8. Grants PRP rewards to the user associated with the provided secretHash.
     *
     * @param secretHash A unique identifier (bytes32) used to associate rewards with a specific user or transaction.
     * @param sellToken The address of the ERC20 token that is being sold/swapped to rebalance debts.
     */
    function rebalanceDebt(bytes32 secretHash, address sellToken) external;

    /**
     * @notice Distributes the accumulated Protocol ZKP fees to designated protocol stakeholders.
     *
     * @dev This external function is responsible for allocating the collected protocol fees in ZKP token
     *      to the treasury and PantherPoolV1 contract (ie PrpConversion facet).
     *      The distribution logic ensures that fees are allocated proportionally based on predefined
     *      allocation percentages.
     */
    function distributeProtocolZkpFees(bytes32 secretHash) external;
}
