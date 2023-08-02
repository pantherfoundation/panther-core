// Transaction types
// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

abstract contract TransactionNoteEmitter {
    // solhint-disable var-name-mixedcase
    uint8 private unused = 0x00;
    uint8 private constant ZACCOUNT_ACTIVATION = 0x01;
    uint240 private _txTypeReserves;

    // Message Types
    uint8 private constant NO_CONTENT = 0x00;

    // solhint-enable var-name-mixedcase

    event TransactionNote(bytes1 txType, bytes content);
}
