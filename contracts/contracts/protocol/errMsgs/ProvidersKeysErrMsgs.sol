// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

string constant ERR_INIT_CONTRACT = "PK:init";

string constant ERR_ONLY_OWNER_OR_KEYRING_OPERATOR = "PK:E1";

string constant ERR_KEYRING_ALREADY_EXISTS = "PK:E2";
string constant ERR_KEYRING_ALREADY_ACTIVATED = "PK:E3";
string constant ERR_KEYRING_NOT_EXISTS = "PK:E4";
string constant ERR_KEYRING_NOT_ACTIVATED = "PK:E5";

string constant ERR_ZERO_KEYRING_OPERATOR = "PK:E6";
string constant ERR_REPETITIVE_KEYRING_OPERATOR = "PK:E7";
string constant ERR_INVALID_KEY_EXPIRY_DATE = "PK:E8";
string constant ERR_REVOKED_KEY = "PK:E9";
string constant ERR_UNAUTHORIZED_KEY_OWNER = "PK:E10";

string constant ERR_INSUFFICIENT_KEY_ALLOCATION = "PK:E11";
string constant ERR_TOO_HIGH_KEY_ALLOCATION = "PK:E12";

string constant ERR_REPETITIVE_TREE_ROOT_UPDATING_STATUS = "ZAR:E13";
string constant ERR_TREE_ROOT_UPDATING_NOT_ALLOWED = "PK:E14";

string constant ERR_TOO_LARGE_LEAF_INPUTS = "PK:E15";
