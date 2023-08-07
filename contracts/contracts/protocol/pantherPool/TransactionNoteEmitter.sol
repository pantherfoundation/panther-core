// Transaction types
// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

abstract contract TransactionNoteEmitter {
    // solhint-disable var-name-mixedcase
    // Transaction Types
    uint8 internal constant TT_ZACCOUNT_ACTIVATION = 0x01;

    // Message Types
    uint8 internal constant MT_VOID = 0x00;
    uint8 internal constant MT_UTXO_CREATION_TIME = 0x60;
    uint8 internal constant MT_UTXO_BUSTREE_UTXO = 0x62;

    // solhint-enable var-name-mixedcase

    event TransactionNote(uint8 txType, bytes content);
}
