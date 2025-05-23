// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

string constant ERR_INIT_CONTRACT = "ZAR:init";

string constant ERR_BLACKLIST_ZACCOUNT_ID = "ZAR:E1";
string constant ERR_BLACKLIST_MASTER_EOA = "ZAR:E2";
string constant ERR_BLACKLIST_PUB_ROOT_SPENDING_KEY = "ZAR:E3";

string constant ERR_DUPLICATED_MASTER_EOA = "ZAR:E4";
string constant ERR_DUPLICATED_NULLIFIER = "ZAR:E5";

string constant ERR_UNKNOWN_ZACCOUNT = "ZAR:E6";

string constant ERR_MISMATCH_ARRAYS_LENGTH = "ZAR:E7";
string constant ERR_REPETITIVE_STATUS = "ZAR:E8";

string constant ERR_INVALID_ZACCOUNT_FLAG_POSITION = "ZAR:E9";
string constant ERR_TOO_LARGE_LEAF_INPUTS = "ZAR:E10";

// string constant ERR_INVALID_EXTRA_INPUT_HASH = "ZAR:E11";
string constant ERR_UNEXPECTED_ZKP_AMOUNT = "ZAR:E12";
string constant ERR_UNEXPECTED_PRP_AMOUNT = "ZAR:E13";
string constant ERR_ZERO_ZACCOUNT_COMMIT = "ZAR:E14";
string constant ERR_ZERO_KYC_MSG_HASH = "ZAR:E15";
string constant ERR_NON_ZERO_ZKP_CHANGE = "ZAR:E16";
string constant ERR_UNEXPECTED_KEY = "ZAR:E17";

string constant ERR_MISMATCH_PUB_SPEND_KEY = "ZAR:E18";
string constant ERR_MISMATCH_PUB_READ_KEY = "ZAR:E19";
