// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {bigintToBytes} from '../utils/bigint-conversions';

const MT_UTXO_CREATE_TIME = 0x60;
const LMT_UTXO_CREATE_TIME_BYTES = 1 + 4;
const MT_UTXO_BUSTREE_IDS = 0x62;
// commitment (32) + queueId (4) + indexInQueue (1) = 37
const LMT_UTXO_BUSTREE_IDS_BYTES = 1 + 37;
const MT_UTXO_ZACCOUNT = 0x06;
// 32 (ephemeralKey) + 64 (secretMsg)
const LMT_UTXO_ZACCOUNT_BYTES = 1 + 32 + 64;

const BYTE_TO_STR_LENGTH_MULTIPLIER = 2;

export type DecodedZAccountActivationTxNote = {
    createTime: number;
    commitment: string;
    queueId: number;
    indexInQueue: number;
    zAccountUTXOMessage: string;
};

export function decodeZAccountActivationTxNote(
    encodedNoteContentHex: string,
): DecodedZAccountActivationTxNote {
    validateInput(encodedNoteContentHex);

    const {createTimeMsgContent, busMsgContent, zAccountMsgContent} =
        parseZAccountActivationTxNoteSegments(encodedNoteContentHex);

    return {
        createTime: parseInt(createTimeMsgContent, 16),
        ...decodeBusTreeIds(busMsgContent),
        zAccountUTXOMessage: `${bigintToBytes(
            BigInt(MT_UTXO_ZACCOUNT),
            1,
        )}${zAccountMsgContent}`,
    };
}

function parseZAccountActivationTxNoteSegments(encodedNoteContentHex: string): {
    createTimeMsgContent: string;
    busMsgContent: string;
    zAccountMsgContent: string;
} {
    const createTimeMsgContent = parseSegment(
        encodedNoteContentHex,
        1,
        LMT_UTXO_CREATE_TIME_BYTES,
        MT_UTXO_CREATE_TIME,
    );
    const busMsgContent = parseSegment(
        encodedNoteContentHex,
        1 + LMT_UTXO_CREATE_TIME_BYTES,
        LMT_UTXO_BUSTREE_IDS_BYTES,
        MT_UTXO_BUSTREE_IDS,
    );

    const zAccountMsgContent = parseSegment(
        encodedNoteContentHex,
        1 + LMT_UTXO_CREATE_TIME_BYTES + LMT_UTXO_BUSTREE_IDS_BYTES,
        LMT_UTXO_ZACCOUNT_BYTES,
        MT_UTXO_ZACCOUNT,
    );

    return {createTimeMsgContent, busMsgContent, zAccountMsgContent};
}

function decodeBusTreeIds(busMsgContent: string): {
    commitment: string;
    queueId: number;
    indexInQueue: number;
} {
    const commitment = `0x${busMsgContent.substr(0, 64)}`;
    const queueId = parseInt(busMsgContent.substr(64, 8), 16);
    const indexInQueue = parseInt(busMsgContent.substr(72, 2), 16);
    return {commitment, queueId, indexInQueue};
}

export function parseSegment(
    plaintextHex: string,
    startByteIndex: number,
    lengthInBytes: number,
    expectedType: number,
): string {
    const startStrIndex = startByteIndex * BYTE_TO_STR_LENGTH_MULTIPLIER;
    const lengthInStr = lengthInBytes * BYTE_TO_STR_LENGTH_MULTIPLIER;
    const msgType = parseInt(
        plaintextHex.substr(startStrIndex, BYTE_TO_STR_LENGTH_MULTIPLIER),
        16,
    );

    if (msgType !== expectedType) {
        throw new Error(
            `Invalid msgType: Expected ${expectedType.toString(
                16,
            )}, got ${msgType.toString(16)}`,
        );
    }
    return plaintextHex.substr(
        startStrIndex + BYTE_TO_STR_LENGTH_MULTIPLIER * 1,
        lengthInStr - BYTE_TO_STR_LENGTH_MULTIPLIER * 1,
    );
}

function validateInput(plaintextBinary: string): void {
    const requiredLengthInBytes =
        1 +
        LMT_UTXO_BUSTREE_IDS_BYTES +
        LMT_UTXO_CREATE_TIME_BYTES +
        LMT_UTXO_ZACCOUNT_BYTES;
    const requiredLengthInStr =
        requiredLengthInBytes * BYTE_TO_STR_LENGTH_MULTIPLIER;

    if (
        typeof plaintextBinary !== 'string' ||
        plaintextBinary.length < requiredLengthInStr
    ) {
        throw new Error('Invalid input');
    }
}
