// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

// ZAccount Tx Type
uint8 constant TT_ZACCOUNT_ACTIVATION = 0x01;
// ZAccount Tx SunTypes
uint8 constant ST_ZACCOUNT_REACTIVATION = 0x0A;
uint8 constant ST_ZACCOUNT_RENEWAL = 0x0B;

// PRP Claim Tx Type
uint8 constant TT_PRP_CLAIM = 0x02;

// PRP Conversion Tx Type
uint8 constant TT_PRP_CONVERSION = 0x03;

// Main Tx Type
uint8 constant TT_MAIN_TRANSACTION = 0x04;
// Main Tx SubTypes
uint8 constant ST_INTERNAL = 0x0C;
uint8 constant ST_DEPOSIT = 0x0D;
uint8 constant ST_WITHDRAWAL = 0x0E;

// TODO: adding message types here
