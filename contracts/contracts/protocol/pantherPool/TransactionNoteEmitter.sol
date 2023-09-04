// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

/***
 * @dev Every MASP transaction is accompanied by the "Transaction Note" - data
 * needed to process the transaction (think of opening UTXOs), reconstruct user
 * operations history (think of "wallet cold start"), or send a private message
 * to a user in extraordinary cases (think of a "subpoena").
 * `PantherPool` smart contract publishes Transaction Notes as "events" (logs).
 * The Transaction Note contains one or a few "messages", which may be "public"
 * or "private".
 * Public messages contain publicly seen on-chain data. Smart contracts, rather
 * than users (the DApp), compose public messages.
 * As the name assumes, private messages contain private data, and user (DApp)
 * prepares and encrypts these messages to pass them to smart contracts.
 * Every private message is encrypted with the reading key of a receiver, who
 * may be a recipient of an UTXO, or the user that spends UTXOs ("messages to
 * the future"), or even a user not involved in spending/creating UTXOs.
 * Smart contracts don't parse private messages but rather copy private messages
 * "as is" into Transaction Notes.
 * Every message belongs to a certain "message type". The message type defines
 * the exact message length and the content.
 * For "fixed-content" messages, the message type defines all data fields - i.e.
 * data interpretation, formats/size, and the sequence the fields must follow in.
 * Data fields of the "free-content" are unspecified, unlike the content size.
 * Public messages always have fixed content. Private messages may have fixed or
 * free content.
 * For fixed-content private messages, the protocol also specifies the content
 * of the preimage and the cipher to apply.
 * Every MASP transaction belongs to one of a few "transaction types".
 * For every transaction type, the protocol specifies "mandatory" messages which
 * MUST be included in the Transaction Note.
 * Users (DApp) may append "optional" messages to mandatory messages.
 * There is also a special "void" message that has no content. It MAY replace a
 * mandatory message when data is missing/undefined/irrelevant, providing public
 * knowledge of this fact does not leak privacy.
 */
abstract contract TransactionNoteEmitter {
    // @notice Transaction Note, emitted with every MASP transaction
    event TransactionNote(uint8 txType, bytes content);

    // **** `bytes content`

    /* START of pseudo-code
    bytes content = abi.packed(messages[0], ..., messages[numMessages - 1]);
    numMessages = for_txType_num_of_mandatory_mssgs + num_of_opt_mssgs;

    // For "void" message type:
    bytes messages[i] = abi.packed(byte msgType);

    // For messages of types other than "void":
    bytes messages[i] = abi.packed(
        byte msgType,
        bytes[for_msgType_length] msgContainer
    );

    // Public fixed-content messages:
    // Smart contract MUST compose `msgContainer` as defined by `msgType`
    // (no `ephemeralKey` needed as data is publicly seen)
    bytes msgContainer = avi.packed(<abi.packed on-chain data>)

    // Private fixed-content messages:
    // DApp MUST compose the `ciphertext` as defined by the `msgType`
    bytes msgContainer = avi.packed(
        bytes32(ephemeralKey),
        bytes[for_msgType_ciphertext_length] ciphertext
    )

    // Private free-data messages:
    // nBlocks - number of 16-byte blocks the `msgContent` occupies
    require(nBlocks >= 1 && nBlocks =< 16)
    msgType = 0x2F + nBlocks;
    // DApp is not limited in composing (structuring) `msgContainer`
    bytes messages[i] = abi.packed(
        byte msgType,
        bytes32(ephemeralKey),
        bytes[nBlocks*16] msgContainer
    )
    END of pseudo-code */

    // **** Transaction Types

    // The range for `uint8 txType` divided into sub-ranges:
    //  - 0x00 .. 0x1F allowed
    //  - 0x20 .. 0xFF reserved (unused)

    // solhint-disable var-name-mixedcase

    uint8 internal constant TT_ZACCOUNT_ACTIVATION = 0x01;
    // TransactionNote for this tx type MUST include in the specified sequence:
    // - MT_UTXO_CREATE_TIME
    // - MT_UTXO_BUSTREE_IDS
    // - MT_UTXO_ZACCOUNT

    // **** Message Types

    // The range for `uint8 msgType` divided into sub-ranges:
    //  - 0x00 - the "void" (empty) message
    //  - 0x01 .. 0x2F for fixed-content private messages
    //  - 0x30 .. 0x3F for free-content private messages
    //  - 0x40 .. 0x5F reserved (unused)
    //  - 0x60 .. 0x7F for fixed-content public messages
    //  - 0x80 .. 0xFF reserved (unused)

    // "Void" type messages contain just this single byte:
    uint8 internal constant MT_VOID = 0x00;
    // Length in bytes
    uint256 internal constant LMT_VOID = 1;

    // zAccount UTXO opening values:
    uint8 internal constant MT_UTXO_ZACCOUNT = 0x06;
    // `msgContainer` MUST include the following data:
    // - bytes[64] cypherText
    // Length in bytes (msgType, ephemeralKey, msgContainer)
    uint256 internal constant LMT_UTXO_ZACCOUNT = 1 + 32 + 64;
    // Preimage of `cipherText` MUST contain (512 bit):
    // - random (256 bit)
    // - networkId (6 bit)
    // - zoneId (16 bit)
    // - nonce (24 bit)
    // - expiryTime (32 bit)
    // - amountZkp (64 bit)
    // - amountPrp (50 bit)
    // - totalAmountPerTimePeriod (64 bit)

    // Creation time of UTXO:
    uint8 internal constant MT_UTXO_CREATE_TIME = 0x60;
    // `msgContainer` MUST include the following data:
    // - uint32 creationTime
    // Length in bytes (msgType, msgContainer)
    uint256 internal constant LMT_UTXO_CREATE_TIME = 1 + 4;

    uint8 internal constant MT_UTXO_SPEND_TIME = 0x61;
    // `msgContainer` MUST include the following data:
    // - uint32 spendType
    // Length in bytes (msgType, msgContainer)
    uint256 internal constant LMT_UTXO_SPEND_TIME = 1 + 4;

    uint8 internal constant MT_UTXO_BUSTREE_IDS = 0x62;
    // `msgContainer` MUST include the following data:
    // - bytes32 commitment
    // - uint32 queueId
    // - uint8 indexInQueue
    // Length in bytes (msgType, msgContainer)
    uint256 internal constant LMT_UTXO_BUSTREE_IDS = 1 + 37;

    // solhint-enable var-name-mixedcase
}
