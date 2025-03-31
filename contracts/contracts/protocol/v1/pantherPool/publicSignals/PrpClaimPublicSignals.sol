// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

// Indexes of public input for the prpAccounting zk-circuit follows

uint256 constant PRP_CLAIM_EXTRA_INPUT_HASH_IND = 0;
uint256 constant PRP_CLAIM_ADDED_AMOUNT_ZKP_IND = 1;
uint256 constant PRP_CLAIM_CHARGED_AMOUNT_ZKP_IND = 2;
uint256 constant PRP_CLAIM_UTXO_OUT_CREATE_TIME_IND = 3;
uint256 constant PRP_CLAIM_DEPOSIT_PRP_AMOUNT_IND = 4;
uint256 constant PRP_CLAIM_WITHDRAW_PRP_AMOUNT_IND = 5;
uint256 constant PRP_CLAIM_UTXO_COMMITMENT_PRIVATE_PART_IND = 6;
uint256 constant PRP_CLAIM_UTXO_SPEND_PUB_KEY_X_IND = 7;
uint256 constant PRP_CLAIM_UTXO_SPEND_PUB_KEY_Y_IND = 8;
uint256 constant PRP_CLAIM_ZASSET_SCALE_IND = 9;
uint256 constant PRP_CLAIM_ZACCOUNT_UTXO_IN_NULLIFIER_IND = 10;
uint256 constant PRP_CLAIM_ZACCOUNT_UTXO_OUT_COMMITMENT_IND = 11;
uint256 constant PRP_CLAIM_ZNETWORK_CHAIN_ID_IND = 12;
uint256 constant PRP_CLAIM_STATIC_MERKLE_ROOT_IND = 13;
uint256 constant PRP_CLAIM_FOREST_MERKLE_ROOT_IND = 14;
uint256 constant PRP_CLAIM_SALT_HASH_IND = 15;
uint256 constant PRP_CLAIM_MAGICAL_CONSTRAINT_IND = 16;
