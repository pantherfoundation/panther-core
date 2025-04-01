// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// ZAccount Tx Type
uint8 constant TT_ZACCOUNT_ACTIVATION = 0x01;
// ZAccount Tx SubTypes
uint8 constant ST_ZACCOUNT_FIRST_ACTIVATION = 0x00;
uint8 constant ST_ZACCOUNT_REACTIVATION = 0x0A;
uint8 constant ST_ZACCOUNT_RENEWAL = 0x0B;

// PRP Claim Tx Type
uint8 constant TT_PRP_CLAIM = 0x02;

// PRP Conversion Tx Type
uint8 constant TT_PRP_CONVERSION = 0x03;

// Main Tx Type
uint8 constant TT_MAIN_TRANSACTION = 0x04;
// Main Tx SubTypes
uint8 constant ST_INTERNAL = 0x00;
uint8 constant ST_DEPOSIT = 0x0C;
uint8 constant ST_WITHDRAWAL = 0x0D;

// TODO: adding message types here
