// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

/***
 * @dev Every MASP transaction is accompanied by the "Transaction Note" - data
 * a front-end needs to process the transaction (e.g. open UTXOs), reconstruct
 * history of operations (on the wallet cold start), or send/receive a private
 * message to "future" self or another user (think of a "subpoena").
 * `PantherPool` smart contract publishes Transaction Notes as "events" (logs).
 * The Transaction Note contains one or a few "messages", which may be "public"
 * or "private".
 * Public messages contain publicly seen on-chain data. Smart contracts, rather
 * than users (the front-end), compose public messages.
 * As the name assumes, private messages contain private data. The front-end
 * prepares and encrypts these messages to pass them to smart contracts.
 * Every private message is encrypted with the reading key of a receiver, who
 * may be a recipient of an UTXO, or the user that spends UTXOs ("messages to
 * the future"), or even a user not involved in spending/creating UTXOs.
 * Smart contracts don't parse private messages but rather copy these messages
 * "as is" into Transaction Notes.
 * Every message belongs to a certain "message type". The message type defines
 * the message length (size) and, for "fixed-content" messages, the content.
 * The Message type of a fixed-content message defines all data fields of the
 * message content - i.e. data formats/size, interpretation, and the sequence
 * the data fields must follow in.
 * For fixed-content private messages, the protocol also specifies the length
 * of the ciphertext and the preimage content (smart contracts neither decrypt,
 * nor parse the ciphertext, nor enforce its correctness).
 * The "free-content" messages are designed for use solely by the front-end.
 * The protocol specifies the length (size) but not the content.
 * Every MASP transaction belongs to one of a few "transaction types".
 * For every transaction type, the protocol specifies "mandatory" messages,
 * which the Transaction Note MUST include.
 * Users (DApp) may append "optional" messages to mandatory messages.
 * There is also a special "void" message that has no content. It MAY replace a
 * mandatory message when data is either missing, or undefined, or irrelevant,
 * providing public knowledge of this fact does not leak privacy.
 */
abstract contract TransactionNoteEmitter {
    // @notice Transaction Note, emitted with every MASP transaction
    event TransactionNote(uint8 txType, bytes content);

    // ******************************
    // **** `bytes content` specs ***
    // ******************************

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

    // For a public fixed-content message, the Smart contract MUST compose
    // the `msgContainer` as defined by the `msgType` of the message
    // (no `ephemeralKey` needed as data is publicly seen)
    bytes msgContainer = avi.packed(<abi.packed on-chain data>)

    // For a private fixed-content messages, the DApp MUST compose the
    // the `msgContainer` with the ephemeral key and the ciphertext
    bytes msgContainer = avi.packed(
        bytes32(ephemeralKey),
        bytes[for_msgType_ciphertext_length] ciphertext
    )
    END of pseudo-code */

    // ***************************
    // **** Transaction Types ****
    // ***************************

    // The range for `uint8 txType` divided into sub-ranges:
    //  - 0x00 .. 0x1F allowed
    //  - 0x20 .. 0xFF reserved (unused)

    // solhint-disable var-name-mixedcase

    uint8 internal constant TT_ZACCOUNT_ACTIVATION = 0x01;
    // TransactionNote for this tx type MUST contain in the specified sequence:
    // - MT_UTXO_CREATE_TIME
    // - MT_UTXO_BUSTREE_IDS (for the new zAccount UTXO)
    // - MT_UTXO_ZACCOUNT
    // Then free-content messages MAY follow.

    uint8 internal constant TT_PRP_CLAIM = 0x02;
    // TransactionNote for this tx type MUST contain messages of these types:
    // - MT_UTXO_CREATE_TIME
    // - MT_UTXO_BUSTREE_IDS (for the re-created zAccount UTXO)
    // - MT_UTXO_ZACCOUNT
    // Then free-content messages MAY follow.

    uint8 internal constant TT_PRP_CONVERSION = 0x03;
    // TransactionNote for this tx type MUST contain messages of these types:
    // - MT_UTXO_CREATE_TIME
    // - MT_UTXO_BUSTREE_IDS (for the re-created zAccount UTXO)
    // - MT_UTXO_ZACCOUNT
    // - MT_UTXO_ZASSET_PUB
    // - MT_UTXO_ZASSET_PRIV
    // Then free-content messages MAY follow.

    uint8 internal constant TT_MAIN_TRANSACTION = 0x04;
    // TransactionNote for this tx type MUST contain messages of these types:
    // - MT_UTXO_CREATE_TIME
    // - MT_UTXO_SPEND_TIME
    // - MT_UTXO_BUSTREE_IDS (for the re-created zAccount UTXO)
    // - MT_UTXO_ZACCOUNT
    // - MT_UTXO_ZASSET
    // - MT_UTXO_ZASSET
    // Then free-content messages MAY follow.

    // ***********************
    // **** Message Types ****
    // ***********************

    // The range for `uint8 msgType` divided into sub-ranges:
    //  - 0x00 - the "void" (empty) message
    //  - 0x01 .. 0x2F for fixed-content private messages
    //  - 0x30 .. 0x3F for free-content private messages
    //  - 0x40 .. 0x5F reserved (unused)
    //  - 0x60 .. 0x7F for fixed-content public messages
    //  - 0x80 .. 0xEF reserved (unused)
    //  - 0xF0 .. 0xFF for free-content public messages

    // "Void" type messages contain just this single byte:
    uint8 internal constant MT_VOID = 0x00;
    // Length in bytes
    uint256 internal constant LMT_VOID = 1;

    // ---- Private data messages ---

    /// Fixed-content private messages

    // Message with (private) data of a zAccount UTXO:
    uint8 internal constant MT_UTXO_ZACCOUNT = 0x06;
    // `msgContainer` MUST contain the following data:
    // - bytes[32] ephemeralKey,
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

    // Message with private data of a partially-hidden zAsset UTXO:
    uint8 internal constant MT_UTXO_ZASSET_PRIV = 0x07;
    // `msgContainer` MUST contain the following data:
    // - bytes[32] ephemeralKey,
    // - bytes[64] cypherText
    // Length in bytes (msgType, ephemeralKey, msgContainer)
    uint256 internal constant LMT_UTXO_ZASSET_PRIV = 1 + 32 + 64;
    // Preimage of `cipherText` MUST contain (388 bit):
    // - random (256 bit)
    // - zAccountId (24 bit)
    // - zAssetId (64 bit)
    // - originNetworkId (6 bit)
    // - targetNetworkId (6 bit)
    // - originZoneId (16 bit)
    // - targetZoneId (16 bit)

    // Message with (private) data of an entirely-hidden zAsset UTXO:
    uint8 internal constant MT_UTXO_ZASSET = 0x08;
    // `msgContainer` MUST contain the following data:
    // - bytes[32] ephemeralKey,
    // - bytes[64] cypherText
    // Length in bytes (msgType, ephemeralKey, msgContainer)
    uint256 internal constant LMT_UTXO_ZASSET = 1 + 32 + 64;
    // Preimage of `cipherText` MUST contain (452 bit):
    // - random (256 bit)
    // - zAccountId (24 bit)
    // - zAssetId (64 bit)
    // - originNetworkId (6 bit)
    // - targetNetworkId (6 bit)
    // - originZoneId (16 bit)
    // - targetZoneId (16 bit)
    // - bytes64 scaledAmount

    /// Free-content private messages
    // Purposely commented out as smart contracts do not use these constants
    // (but to keep the specs complete, values provided as comments)

    // uint8 internal constant MT_FREE_PRIV_ONE_BLOCK = 0x30;
    // `msgContainer` MUST contain:
    // - bytes[32] ephemeralKey,
    // - bytes[16] cypherText (single 16-byte block)
    // uint8 internal constant LMT_FREE_PRIV_ONE_BLOCK = 1 + 32 + 16;

    // uint8 internal constant MT_FREE_PRIV_TWO_BLOCKS = 0x31;
    // `msgContainer` MUST contain:
    // - bytes[32] ephemeralKey,
    // - bytes[32] cypherText (two 16-byte blocks)
    // uint8 internal constant LMT_FREE_PRIV_TWO_BLOCKS = 1 + 32 + 32;

    // ---- Public data messages ----

    /// Fixed-content public messages

    // Message with the creation time of UTXO(s):
    uint8 internal constant MT_UTXO_CREATE_TIME = 0x60;
    // `msgContainer` MUST contain the following (publicly seen) data:
    // - uint32 creationTime
    // Length in bytes (msgType, msgContainer)
    uint256 internal constant LMT_UTXO_CREATE_TIME = 1 + 4;

    // Message with the spend time of UTXO(s):
    uint8 internal constant MT_UTXO_SPEND_TIME = 0x61;
    // `msgContainer` MUST contain the following (publicly seen) data:
    // - uint32 spendType
    // Length in bytes (msgType, msgContainer)
    uint256 internal constant LMT_UTXO_SPEND_TIME = 1 + 4;

    // Message with the indexes of a UTXO in the "Bus Tree Queues":
    uint8 internal constant MT_UTXO_BUSTREE_IDS = 0x62;
    // `msgContainer` MUST contain the following (publicly seen) data:
    // - bytes32 commitment
    // - uint32 queueId
    // - uint8 indexInQueue
    // Length in bytes (msgType, msgContainer)
    uint256 internal constant LMT_UTXO_BUSTREE_IDS = 1 + 37;

    // Message with public data of a partially-hidden zAsset UTXO:
    uint8 internal constant MT_UTXO_ZASSET_PUB = 0x63;
    // `msgContainer` MUST contain the following (publicly seen) data:
    // - bytes64 scaledAmount
    // (createTime included in the MT_UTXO_CREATE_TIME and skipped here)
    uint256 internal constant LMT_UTXO_ZASSET_PUB = 1 + 8;

    /// Free-content public messages
    // Purposely commented out as smart contracts do not use these constants
    // (but to keep the specs complete, values provided as comments)

    /*
    uint8 internal constant MT_FREE_PUB_ONE_BLOCK = 0xF0;
    // `msgContainer` MUST contain exactly 1 16-byte block:
    uint8 internal constant LMT_FREE_PUB_ONE_WORD = 1 + 16;

    uint8 internal constant MT_FREE_PUB_TWO_BLOCKS = 0xF1;
    // `msgContainer` MUST contain exactly 2 x 16-byte blocks:
    uint8 internal constant LMT_FREE_PUB_TWO_BLOCKS = 1 + 32;
    */

    // solhint-enable var-name-mixedcase
}
