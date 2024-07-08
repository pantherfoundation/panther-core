// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// TODO: Reorder the err messages
string constant ERR_INIT = "PP:E1";
string constant ERR_UNAUTHORIZED = "PP:E2";
string constant ERR_UNDEFINED_CIRCUIT = "PP:E3";
string constant ERR_INVALID_PANTHER_TREES_ROOT = "PP:E4";
string constant ERR_FAILED_ZK_PROOF = "PP:E5";
string constant ERR_INVALID_CREATE_TIME = "PP:E6";
string constant ERR_ZERO_NULLIFIER = "PP:E7";
string constant ERR_ZERO_ZACCOUNT_COMMIT = "PP:E8"; // TODO: Delete it, PP:E39 is used
string constant ERR_ZERO_KYC_MSG_HASH = "PP:E9";
string constant ERR_ZERO_SALT_HASH = "PP:E10";
string constant ERR_ZERO_MAGIC_CONSTR = "PP:E11";
string constant ERR_NOT_WELLFORMED_SECRETS = "PP:E12";
string constant ERR_ZERO_EXTRA_INPUT_HASH = "PP:E13";
string constant ERR_SPENT_NULLIFIER = "PP:E14";
string constant ERR_TOO_LARGE_PRP_AMOUNT = "PP:E15";
string constant ERR_ZERO_ZASSET_SCALE = "PP:E16";
string constant ERR_INVALID_CHAIN_ID = "PP:E17";

string constant ERR_ZERO_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX = "PP:E18";
string constant ERR_ZERO_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX = "PP:E19";
string constant ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER = "PP:E20";
string constant ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER = "PP:E21";
string constant ERR_ZERO_KYT_DEPOSIT_SIGNED_MESSAGE_HASH = "PP:E22";
string constant ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER = "PP:E23";
string constant ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER = "PP:E24";
string constant ERR_ZERO_KYT_WITHDRAW_SIGNED_MESSAGE_HASH = "PP:E25";
string constant ERR_ZERO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX = "PP:E26";
string constant ERR_ZERO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX = "PP:E27";
string constant ERR_ZERO_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX = "PP:E28";
string constant ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX = "PP:E29";

string constant ERR_ZERO_TOKEN = "PP:E30";
string constant ERR_NON_ZERO_TOKEN = "PP:E31";
string constant ERR_ZERO_ZASSET_NULLIFIER = "PP:E32";
string constant ERR_SPENT_ZASSET_NULLIFIER = "PP:E33";
string constant ERR_INVALID_SPEND_TIME = "PP:E34";
string constant ERR_INVALID_EXTRA_INPUT_HASH = "PP:E35";
string constant ERR_TOO_LOW_CHARGED_ZKP = "PP:E36";
string constant ERR_DUPLICATED_KYT_MESSAGE_HASH = "PP:E37";
string constant ERR_INVALID_STATIC_ROOT = "PP:E38";
string constant ERR_ZERO_COMITMENT = "PP:E39";
string constant ERR_INVALID_VAULT_ADDRESS = "PP:E40";
string constant ERR_UNKNOWN_PLUGIN = "PP:E41";
