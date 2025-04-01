// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../core/utils/TransactionNoteEmitter.sol";

contract MockTransactionNoteEmitter is TransactionNoteEmitter {
    event LogPrivateMessage(bytes privateMessage);

    function internalSanitizePrivateMessage(
        bytes memory privateMessages,
        uint16 txType
    ) external {
        _sanitizePrivateMessage(privateMessages, txType);

        emit LogPrivateMessage(privateMessages);
    }
}
