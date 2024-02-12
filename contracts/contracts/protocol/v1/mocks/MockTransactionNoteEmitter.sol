// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../pantherPool/TransactionNoteEmitter.sol";

contract MockTransactionNoteEmitter is TransactionNoteEmitter {
    event LogPrivateMessage(bytes privateMessage);

    function internalSanitizePrivateMessage(
        bytes memory privateMessages,
        uint8 txType
    ) external {
        _sanitizePrivateMessage(privateMessages, txType);

        emit LogPrivateMessage(privateMessages);
    }
}
