// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

uint256 constant EXEC_PLUGIN_EXTRA_INPUTS_HASH = 0; // [0] - extraInputsHash;
uint256 constant EXEC_PLUGIN_DEPOSIT_AMOUNT = 1; // [1] - depositAmount;
uint256 constant EXEC_PLUGIN_WITHDRAW_AMOUNT = 2; // [2] - withdrawAmount;
uint256 constant EXEC_PLUGIN_DONATED_AMOUNT_ZKP = 3; // [3] - donatedAmountZkp;
uint256 constant EXEC_PLUGIN_TOKEN_IN = 4; // [4] - tokenIn;
uint256 constant EXEC_PLUGIN_TOKEN_OUT = 5; // [5] - tokenOut;
uint256 constant EXEC_PLUGIN_TOKEN_IN_ID = 6; // [6] - tokenInId;
uint256 constant EXEC_PLUGIN_TOKEN_OUT_ID = 7; // [7] - tokenOutId;
uint256 constant EXEC_PLUGIN_SPEND_TIME = 8; // [8] - spendTime;
uint256 constant EXEC_PLUGIN_UTXO_IN_NULLIFIER_1 = 9; // [9] - utxoInNullifier1;
uint256 constant EXEC_PLUGIN_UTXO_IN_NULLIFIER_2 = 10; // [10] - utxoInNullifier2;
uint256 constant EXEC_PLUGIN_ZACCOUNT_UTXO_IN_NULLIFIER = 11; // [11] - zAccountUtxoInNullifier;
uint256 constant EXEC_PLUGIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX = 12; // [12] - zZoneDataEscrowEphimeralPubKeyAx;
uint256 constant EXEC_PLUGIN_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX = 13; // [13] - zZoneDataEscrowEncryptedMessageAx;
uint256 constant EXEC_PLUGIN_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER = 14; // [14] - kytDepositSignedMessageSender;
uint256 constant EXEC_PLUGIN_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER = 15; // [15] - kytDepositSignedMessageReceiver;
uint256 constant EXEC_PLUGIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH = 16; // [16] - kytDepositSignedMessageHash;
uint256 constant EXEC_PLUGIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER = 17; // [17] - kytWithdrawSignedMessageSender;
uint256 constant EXEC_PLUGIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER = 18; // [18] - kytWithdrawSignedMessageReceiver;
uint256 constant EXEC_PLUGIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH = 19; // [19] - kytWithdrawSignedMessageHash;
uint256 constant EXEC_PLUGIN_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX = 20; // [20] - dataEscrowEphimeralPubKeyAx;
uint256 constant EXEC_PLUGIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX = 21; // [21] - dataEscrowEncryptedMessageAx;
uint256 constant EXEC_PLUGIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX = 22; // [22] - daoDataEscrowEphimeralPubKeyAx;
uint256 constant EXEC_PLUGIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX = 23; // [23] - daoDataEscrowEncryptedMessageAx;
uint256 constant EXEC_PLUGIN_UTXO_OUT_CREATE_TIME = 24; // [24] - utxoOutCreateTime;
uint256 constant EXEC_PLUGIN_UTXO_OUT_COMMITMENT_1 = 25; // [25] - utxoOutCommitment1;
uint256 constant EXEC_PLUGIN_UTXO_OUT_COMMITMENT_2 = 26; // [26] - utxoOutCommitment2;
uint256 constant EXEC_PLUGIN_ZACCOUNT_UTXO_OUT_COMMITMENT = 27; // [27] - zAccountUtxoOutCommitment;
uint256 constant EXEC_PLUGIN_CHARGED_AMOUNT_ZKP = 28; // [28] - chargedAmountZkp;
uint256 constant EXEC_PLUGIN_ZNETWORK_CHAIN_ID = 29; // [29] - zNetworkChainId;
uint256 constant EXEC_PLUGIN_FOREST_MERKLE_ROOT = 30; // [30] - forestMerkleRoot;
uint256 constant EXEC_PLUGIN_SALT_HASH = 31; // [31] - saltHash;
uint256 constant EXEC_PLUGIN_MAGICAL_CONSTRAINT = 32; // [32] - magicalConstraint;
