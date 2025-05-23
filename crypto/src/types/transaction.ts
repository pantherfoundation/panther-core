// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

export enum TxType {
    ZAccountActivation = 0x100, // Type1
    ZAccountRenewal = 0x102, // Type??
    PrpClaiming = 0x103, // Type2
    PrpConversion = 0x104, // Type3
    ZTransaction = 0x105, // Type4
    Deposit = 0x105 | 0x10, // Type4
    Withdrawal = 0x105 | 0x20, // Type4
    ZSwap = 0x106, // Type5
}
