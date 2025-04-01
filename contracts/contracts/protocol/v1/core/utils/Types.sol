// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

uint16 constant TT_ZACCOUNT_ACTIVATION = 0x100;
uint16 constant TT_ZACCOUNT_REACTIVATION = 0x101;
uint16 constant TT_ZACCOUNT_RENEWAL = 0x102;
uint16 constant TT_PRP_ACCOUNTING = 0x103;
uint16 constant TT_PRP_CONVERSION = 0x104;

// Main Tx Type
/***
 * This TX Type is supposed to be generated based upon the tx:
 * for a Deposit tx: TT_MAIN_TRANSACTION | TF_DEPOSIT_TRANSACTION = 0x115 // 277
 * for a Withdrawal tx: TT_MAIN_TRANSACTION | TF_WITHDRAWAL_TRANSACTION = 0x125 // 293
 * if a tx is both Withdrawal and Deposit:
 * TT_MAIN_TRANSACTION | TF_WITHDRAWAL_TRANSACTION | TF_DEPOSIT_TRANSACTION = 0x135 // 309
 */

uint16 constant TT_MAIN_TRANSACTION = 0x105;
// Main Tx Flags
uint16 constant TF_DEPOSIT_TRANSACTION = 0x10; // 16
uint16 constant TF_WITHDRAWAL_TRANSACTION = 0x20; // 32

uint16 constant TT_ZSWAP = 0x106;

// Bit Masks
uint16 constant TM_CLEAR_FLAGS = 0xFF0F;
