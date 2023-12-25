// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {TxNoteType1, TxNoteType3, TxNoteType4} from 'types/note';

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
};

// Length Constants
const LMT = {
    CreateTime: 1 + 4, // 1 byte for message type, 4 bytes for createTime
    BusTreeIds: 1 + 37, // 1 byte for message type, 32 bytes for commitment, 4 bytes for queueId, 1 byte for indexInQueue
    ZAccount: 1 + 32 + 64, // 1 byte for message type, 32 bytes for ephemeral public key, 64 bytes for encrypted private message
    ZAssetPub: 1 + 8, // 1 byte for message type, 8 bytes for zkpAmountScaled
    ZAssetPriv: 1 + 32 + 64, // 1 byte for message type, 32 bytes for ephemeral public key, 64 bytes for encrypted private message
    ZAsset: 1 + 32 + 64, // 1 byte for message type, 32 byte random, 64 byte secret message
    SpentUTXO: 1 + 32 + 64, // 1 byte for message type, 32 bytes for ephemeral public key, 64 bytes spentUtxoCommitment1 spentUtxoCommitment2
};

export enum TxNoteType {
    ZAccountActivation = 0x01, // Type1
    PrpClaiming = 0x02, // Type2
    PrpConversion = 0x03, // Type3
    ZTransaction = 0x4, // Type4
}

type Segment = {type: number; length: number};

// Segment Configurations for each transaction note type
const SegmentConfigs: {[key in TxNoteType]: Segment[]} = {
    [TxNoteType.ZAccountActivation]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
    ],
    [TxNoteType.PrpClaiming]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
    ],
    [TxNoteType.PrpConversion]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAssetPub, length: LMT.ZAssetPub},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAssetPriv, length: LMT.ZAssetPriv},
    ],
    [TxNoteType.ZTransaction]: [
        {type: MT.CreateTime, length: LMT.CreateTime},
        {type: MT.BusTreeIds, length: LMT.BusTreeIds},
        {type: MT.ZAccount, length: LMT.ZAccount},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.ZAsset, length: LMT.ZAsset},
        {type: MT.SpentUTXO, length: LMT.SpentUTXO},
    ],
};

const BYTES_TO_STRING_LENGTH_FACTOR = 2;

/**
 * Function to decode transaction note
 * @param {string} encodedNoteContentHex - The encoded Note Content Hex
 * @param {TxNoteType} noteType - The Note Type
 * @returns {TxNoteType1 | TxNoteType3 | TxNoteType4} - returns either a TxNoteType1,
 * TxNoteType3 or TxNoteType4 depending on noteType
 */
export function decodeTxNote(
    encodedNoteContentHex: string,
    noteType: TxNoteType,
): TxNoteType1 | TxNoteType3 | TxNoteType4 {
    const config = SegmentConfigs[noteType];
    validateInput(encodedNoteContentHex, 1 + getRequiredLength(config));
    const segments = parseSegments(encodedNoteContentHex, config);

    const createTime = parseInt(segments[0], 16);
    const busTreeIds = decodeBusTreeIds(segments[1]);

    // Use switch for future extensibility
    switch (noteType) {
        case TxNoteType.ZAccountActivation:
        case TxNoteType.PrpClaiming:
            // For ZAccountActivation and PrpClaiming, we decode common fields
            // only
            return {
                createTime,
                ...busTreeIds,
                zAccountUTXOMessage: prependMessageType(
                    MT.ZAccount,
                    segments[2],
                ),
            } as TxNoteType1;

        case TxNoteType.PrpConversion:
            // For PrpConversion, we additionally decode zkpAmountScaled,
            // zAssetUTXOMessage, and commitment of the newly created zAsset
            return {
                createTime,
                ...busTreeIds,
                zkpAmountScaled: BigInt(`0x${segments[2]}`),
                zAccountUTXOMessage: prependMessageType(
                    MT.ZAccount,
                    segments[3],
                ),
                zAssetUTXOMessage: prependMessageType(
                    MT.ZAssetPriv,
                    segments[4],
                ),
            } as TxNoteType3;

        case TxNoteType.ZTransaction:
            const [, , zAccount, zAsset1, zAsset2, spentUTXO] = segments;
            return {
                createTime,
                ...busTreeIds,
                zAccount: prependMessageType(MT.ZAccount, zAccount),
                zAsset1: prependMessageType(MT.ZAsset, zAsset1),
                zAsset2: prependMessageType(MT.ZAsset, zAsset2),
                spentUTXO: prependMessageType(MT.SpentUTXO, spentUTXO),
            } as TxNoteType4;
        // ZTransaction
        default:
            throw new Error(`Unsupported note type: ${noteType}`);
    }
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

    return segments.map(({type, length}) => {
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
                `Invalid msgType: Expected ${type.toString(
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
