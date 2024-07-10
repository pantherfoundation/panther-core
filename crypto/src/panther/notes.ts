// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {
    ZAccountActivationNote,
    PrpConversionNote,
    ZTransactionNote,
    ZSwapNote,
    TxNote,
} from 'types/note';

import {TxType} from '../types/transaction';
import {bigintToBytes} from '../utils/bigint-conversions';

// for reference, see contracts/protocol/pantherPool/TransactionNoteEmitter.sol
// Message Type Constants
const MT = {
    CreateTime: 0x60,
    BusTreeIds: 0x62,
    ZAccount: 0x06,
    ZAssetPub: 0x63,
    ZAssetPriv: 0x07,
    ZAsset: 0x08,
    SpentUTXO: 0x09,
    SpendTime: 0x61,
};

// Length Constants
const LMT = {
    CreateTime: 1 + 4, // 1 byte for message type, 4 bytes for createTime
    SpendTime: 1 + 4, // 1 byte for message type, 4 bytes for spendTime
    BusTreeIds: 1 + 37, // 1 byte for message type, 32 bytes for commitment, 4 bytes for queueId, 1 byte for indexInQueue
    ZAccount: 1 + 32 + 64, // 1 byte for message type, 32 bytes for ephemeral public key, 64 bytes for encrypted private message
    ZAssetPub: 1 + 8, // 1 byte for message type, 8 bytes for zkpAmountScaled
    ZAssetPriv: 1 + 32 + 64, // 1 byte for message type, 32 bytes for ephemeral public key, 64 bytes for encrypted private message
    ZAsset: 1 + 32 + 64, // 1 byte for message type, 32 byte random, 64 byte secret message
    SpentUTXO: 1 + 32 + 64, // 1 byte for message type, 32 bytes for ephemeral public key, 64 bytes spentUtxoCommitment1 spentUtxoCommitment2
};

type Segment = {type: number; length: number};

// Segment Configurations for each transaction note type
const SegmentConfigs: {[key in TxType]: Segment[]} = {
    [TxType.ZAccountActivation]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
    ],
    [TxType.PrpClaiming]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
    ],
    [TxType.PrpConversion]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAssetPub, length: LMT.ZAssetPub},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAssetPriv, length: LMT.ZAssetPriv},
    ],
    [TxType.ZTransaction]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.SpendTime, length: LMT.SpendTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.SpentUTXO, length: LMT.SpentUTXO},
    ],
    [TxType.Deposit]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.SpendTime, length: LMT.SpendTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.SpentUTXO, length: LMT.SpentUTXO},
    ],
    [TxType.Withdrawal]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.SpendTime, length: LMT.SpendTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.SpentUTXO, length: LMT.SpentUTXO},
    ],
    [TxType.ZSwap]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.SpendTime, length: LMT.SpendTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAssetPub, length: LMT.ZAssetPub},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.ZAssetPriv, length: LMT.ZAssetPriv},
        {type: MT.SpentUTXO, length: LMT.SpentUTXO},
    ],
};

const BYTES_TO_STRING_LENGTH_FACTOR = 2;

/**
 * Function to decode transaction note
 * @param {string} encodedNoteContentHex - The encoded Note Content Hex
 * @param {TxType} txType - The Note Type
 * @returns {ZAccountActivationNote | PrpConversionNote | ZTransactionNote} - returns either a ZAccountActivationNote,
 * PrpConversionNote or ZTransactionNote depending on noteType
 */
/**
 * Decodes a transaction note based on the provided encoded content and transaction type.
 * @param encodedNoteContentHex - The hexadecimal encoded note content.
 * @param txType - The type of the transaction.
 * @returns The decoded note object.
 */
export function decodeTxNote(
    encodedNoteContentHex: string,
    txType: TxType,
): TxNote {
    const config = SegmentConfigs[txType];
    validateInput(encodedNoteContentHex, 1 + getRequiredLength(config));
    const segments = parseSegments(encodedNoteContentHex, config);

    switch (txType) {
        case TxType.ZAccountActivation:
        case TxType.PrpClaiming:
            return decodeZAccountActivationNote(segments, txType);
        case TxType.PrpConversion:
            return decodePrpConversionNote(segments, txType);
        case TxType.ZTransaction:
        case TxType.Deposit:
        case TxType.Withdrawal:
            return decodeZTransactionNote(segments, txType);
        case TxType.ZSwap:
            return decodeZSwapNote(segments, txType);
        default:
            throw new Error(`Unsupported note type: ${txType}`);
    }
}

function decodeZAccountActivationNote(
    segments: string[],
    txType: TxType,
): ZAccountActivationNote {
    const [createTime, busTreeIds, zAccountMsg] = segments;
    return {
        createTime: parseInt(createTime, 16),
        ...decodeBusTreeIds(busTreeIds),
        zAccountUTXOMessage: prependMessageType(MT.ZAccount, zAccountMsg),
        txType,
    };
}

function decodePrpConversionNote(
    segments: string[],
    txType: TxType,
): PrpConversionNote {
    const [createTime, busTreeIds, zAssetPub, zAccountMsg, zAssetPriv] =
        segments;

    return {
        createTime: parseInt(createTime, 16),
        ...decodeBusTreeIds(busTreeIds),
        zkpAmountScaled: BigInt(`0x${zAssetPub}`),
        zAccountUTXOMessage: prependMessageType(MT.ZAccount, zAccountMsg),
        zAssetUTXOMessage: prependMessageType(MT.ZAssetPriv, zAssetPriv),
        txType,
    };
}

function decodeZTransactionNote(
    segments: string[],
    txType: TxType,
): ZTransactionNote {
    const [
        createTime,
        spendTime,
        busTreeIds,
        zAccount,
        zAsset1,
        zAsset2,
        spentUTXO,
    ] = segments;
    return {
        createTime: parseInt(createTime, 16),
        spendTime: parseInt(spendTime, 16),
        ...decodeBusTreeIds(busTreeIds),
        zAccountUTXOMessage: prependMessageType(MT.ZAccount, zAccount),
        zAssetUTXOMessages: [
            prependMessageType(MT.ZAsset, zAsset1),
            prependMessageType(MT.ZAsset, zAsset2),
        ],
        spentUTXOCommitmentMessage: prependMessageType(MT.SpentUTXO, spentUTXO),
        txType,
    };
}

function decodeZSwapNote(segments: string[], txType: TxType): ZSwapNote {
    const [
        createTime,
        spendTime,
        busTreeIds,
        amountScaled,
        zAccount,
        zAsset,
        zAssetPriv,
        spentUTXO,
    ] = segments;
    return {
        createTime: parseInt(createTime, 16),
        spendTime: parseInt(spendTime, 16),
        ...decodeBusTreeIds(busTreeIds),
        amountScaled: BigInt(`0x${amountScaled}`),
        zAccountUTXOMessage: prependMessageType(MT.ZAccount, zAccount),
        zAssetUTXOMessages: [
            prependMessageType(MT.ZAsset, zAsset),
            prependMessageType(MT.ZAssetPriv, zAssetPriv),
        ],

        spentUTXOCommitmentMessage: prependMessageType(MT.SpentUTXO, spentUTXO),
        txType,
    };
}

/**
 * Helper function to decode BusTree IDs
 * @param {string} busMsgContent - The bus message content string
 * @returns {object} - An object containing decoded BusTree IDs
 */
function decodeBusTreeIds(busMsgContent: string): {
    commitment: string;
    queueId: number;
    indexInQueue: number;
} {
    let cursor = 0;
    const commitment = `0x${busMsgContent.slice(cursor, (cursor += 64))}`;
    const queueId = parseInt(busMsgContent.slice(cursor, (cursor += 8)), 16);
    const indexInQueue = parseInt(
        busMsgContent.slice(cursor, (cursor += 2)),
        16,
    );

    return {commitment, queueId, indexInQueue};
}

/**
 * Helper function to parse segments
 * @param {string} encodedNoteContentHex - The encoded Note Content Hex string
 * @param {Segment[]} segments - The segments configurations
 * @returns {string[]} - An array of parsed segments
 */
function parseSegments(
    encodedNoteContentHex: string,
    segments: Segment[],
): string[] {
    let startStrIndex = 1 * BYTES_TO_STRING_LENGTH_FACTOR;
    console.log(segments);

    return segments.map(({type, length}, index) => {
        const lengthInStr = length * BYTES_TO_STRING_LENGTH_FACTOR;
        const msgType = parseInt(
            encodedNoteContentHex.slice(
                startStrIndex,
                startStrIndex + BYTES_TO_STRING_LENGTH_FACTOR,
            ),
            16,
        );

        if (msgType !== type) {
            throw new Error(
                `Invalid msgType[${index}]: Expected ${type.toString(
                    16,
                )}, got ${msgType.toString(16)}`,
            );
        }

        return encodedNoteContentHex.slice(
            startStrIndex + BYTES_TO_STRING_LENGTH_FACTOR,
            (startStrIndex += lengthInStr),
        );
    });
}

/**
 * Helper function to prepend a message type to the content
 * @param {number} type - The message type to prepend
 * @param {string} content - The content to which the message type is prepended
 * @returns {string} - The new content string with prepended message type
 */
function prependMessageType(type: number, content: string): string {
    return `${bigintToBytes(BigInt(type), 1)}${content}`;
}

/**
 * Helper function to validate input
 * @param {string} plaintextBinary - The input string
 * @param {number} requiredLengthInBytes - The required length of the input
 * string
 */
function validateInput(
    plaintextBinary: string,
    requiredLengthInBytes: number,
): void {
    const requiredLengthInStr =
        requiredLengthInBytes * BYTES_TO_STRING_LENGTH_FACTOR;

    if (
        typeof plaintextBinary !== 'string' ||
        plaintextBinary.length < requiredLengthInStr
    ) {
        throw new Error(
            'Invalid input. The provided string may not be long enough or it is not of type string.',
        );
    }
}

/**
 * Helper function to calculate required length
 * @param {Segment[]} segments - The array of segments
 * @returns {number} - The total length calculated
 */
function getRequiredLength(segments: Segment[]): number {
    return segments.reduce((total, segment) => total + segment.length, 0);
}
