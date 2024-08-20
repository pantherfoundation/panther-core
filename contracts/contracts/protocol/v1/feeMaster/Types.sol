// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

struct Providers {
    address pantherPool;
    address pantherBusTree;
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

struct FeeData {
    uint16 txType;
    uint8 numOutputUtxos;
    uint40 scPaymasterZkpFee;
    uint40 scAddedZkpAmount;
    uint40 scChargedZkpAmount;
}

struct AssetData {
    address tokenAddress;
    uint128 depositAmount;
    uint128 withdrawAmount;
}
