// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

export enum TxType {
    ZAccountActivation = 0x100, // Type1
    PrpClaiming = 0x103, // Type2
    PrpConversion = 0x104, // Type3
    ZTransaction = 0x105, // Type4
    Deposit = 0x105 | 0x10, // Type4
    Withdrawal = 0x105 | 0x20, // Type4
    ZSwap = 0x106, // Type5
}
