// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

struct Pool {
    address _address;
    address _token0;
    address _token1;
    bool _enabled;
}

struct Providers {
    address pantherPool;
    address pantherTrees;
    address paymaster;
    address trustProvider;
}

struct FeeParams {
    // Min zkp per utxo, divided by 1e12
    uint32 scPerUtxoReward;
    // Charged amount per kyt, divided by 1e12
    uint32 scPerKytFee;
    // Charged amount for kyc, divided by 1e12
    uint32 scKycFee;
    // Percentage of fee, scaled by 100 (e.g. 2000 means 20%)
    uint16 protocolFeePercentage;
}

// Charged fees per each transaction, each value is divided by 1e12, except protocol fee
struct ChargedFeesPerTx {
    uint40 scMiningReward;
    uint40 scKytFees;
    uint40 scKycFee;
    uint40 scPaymasterCompensationInNative;
    uint96 protocolFee;
}

/**
 * @dev Represents the fee-related data for a transaction.
 * @param txType The type identifier of the transaction.
 * @param numOutputUtxos The number of output UTXOs in the transaction.
 * @param scPaymasterZkpFee The scaled ZKP fee allocated for paymaster compensation (scaled by 1e12).
 * @param scAddedZkpAmount The scaled ZKP amount donated by the FeeMaster (scaled by 1e12).
 * @param scChargedZkpAmount The scaled total ZKP amount charged to the user (scaled by 1e12).
 */
struct FeeData {
    uint16 txType;
    uint8 numOutputUtxos;
    uint40 scPaymasterZkpFee;
    uint40 scAddedZkpAmount;
    uint40 scChargedZkpAmount;
}

/**
 * @dev Represents the asset-related data for a transaction.
 * @param tokenAddress The address of the transacted token.
 * @param depositAmount The deposited amount. it can be 0.
 * @param withdrawAmount The withdrawn amount. it can be 0.
 */
struct AssetData {
    address tokenAddress;
    uint128 depositAmount;
    uint128 withdrawAmount;
}
