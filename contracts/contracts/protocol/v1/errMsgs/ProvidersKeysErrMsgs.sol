// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

string constant ERR_INIT_CONTRACT = "PK:init";

string constant ERR_INCORRECT_SIBLINGS_SIZE = "PK:E02";

string constant ERR_TREE_LOCK_ALREADY_UPDATED = "PK:E05";
string constant ERR_TREE_IS_LOCKED = "PK:E06";

string constant ERR_INSUFFICIENT_ALLOCATION = "PK:E10";
string constant ERR_TOO_HIGH_ALLOCATION = "PK:E11";

string constant ERR_KEYRING_ALREADY_ACTIVATED = "PK:15";
string constant ERR_KEYRING_NOT_EXISTS = "PK:E16";
string constant ERR_KEYRING_NOT_ACTIVATED = "PK:E17";

string constant ERR_UNAUTHORIZED_OPERATOR = "PK:E20";
string constant ERR_ZERO_OPERATOR_ADDRESS = "PK:E21";
string constant ERR_SAME_OPERATOR = "PK:E22";

string constant ERR_REVOKED_KEY = "PK:E25";
string constant ERR_INVALID_KEY_EXPIRY = "PK:E26";
string constant ERR_KEY_IS_NOT_IN_KEYRING = "PK:E27";
