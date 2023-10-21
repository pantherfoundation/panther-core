// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {
    decryptCipherText,
    encryptPlainText,
    generateEcdhSharedKey,
} from '../base/encryption';
import {generateRandomInBabyJubSubField} from '../base/field-operations';
import {
    packPublicKey,
    derivePubKeyFromPrivKey,
    unpackPublicKey,
    PACKED_PUB_KEY_SIZE,
} from '../base/keypairs';
import {PublicKey, PrivateKey, ephemeralKeyPacked} from '../types/keypair';
import {
    ICiphertext,
    UTXOMessage,
    ZAccountUTXOMessage,
    ZAssetUTXOMessage,
} from '../types/message';
import {assertInBabyJubJubSubOrder, assertMaxBits} from '../utils/assertions';
import {
    bigIntToUint8Array,
    uint8ArrayToBigInt,
    bigintToBytes,
    bigintToBinaryString,
} from '../utils/bigint-conversions';

const EPHEMERAL_KEY_WIDTH = PACKED_PUB_KEY_SIZE * 2;
const MSG_TYPE_WIDTH = 2;

const FIELD_BIT_LENGTHS = {
    secretRandom: 256,
    zAccountId: 24,
    zAssetId: 64,
    originNetworkId: 6,
    targetNetworkId: 6,
    originZoneId: 16,
    targetZoneId: 16,
    networkId: 6,
    zoneId: 16,
    nonce: 16,
    expiryTime: 32,
    amountZkp: 64,
    amountPrp: 58,
    totalAmountPerTimePeriod: 64,
} as const;

const FIELD_ALLOWED_VALUES = {
    zoneId: 2n,
    originZoneId: 1n,
    targetZoneId: 1n,
    networkId: 2n,
    originNetworkId: 2n,
    targetNetworkId: 2n,
} as const;

enum UTXOMessageType {
    ZAccount = 'ZAccount',
    ZAsset = 'ZAsset',
}

type UtxoMessageConfig = {
    [key in UTXOMessageType]: {
        fields: Array<keyof UTXOMessage>;
        size: number;
        msgType: string;
    };
};

const UTXO_MESSAGE_CONFIGS: UtxoMessageConfig = {
    ZAccount: {
        fields: [
            'secretRandom',
            'networkId',
            'zoneId',
            'nonce',
            'expiryTime',
            'amountZkp',
            'amountPrp',
            'totalAmountPerTimePeriod',
        ],
        size: 64,
        msgType: '06',
    },
    ZAsset: {
        fields: [
            'secretRandom',
            'zAccountId',
            'zAssetId',
            'originNetworkId',
            'targetNetworkId',
            'originZoneId',
            'targetZoneId',
        ],
        size: 64, // actual size is 388 bit (49 bytes) but we need to round up to the nearest byte that is a multiple of 16 because of AES-128-CBC
        msgType: '07',
    },
};

export function unpackAndDecryptZAccountUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
): ZAccountUTXOMessage {
    const zAccountMsg = unpackAndDecryptUTXOMessage(
        message,
        rootReadingPrivateKey,
        UTXOMessageType.ZAccount,
    ) as ZAccountUTXOMessage;

    validateFields(zAccountMsg, ['networkId', 'zoneId']);
    return zAccountMsg;
}

export function unpackAndDecryptZAssetUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
): ZAssetUTXOMessage {
    const zAssetMsg = unpackAndDecryptUTXOMessage(
        message,
        rootReadingPrivateKey,
        UTXOMessageType.ZAsset,
    ) as ZAssetUTXOMessage;

    validateFields(zAssetMsg, [
        'originNetworkId',
        'targetNetworkId',
        'originZoneId',
        'targetZoneId',
    ]);

    return zAssetMsg;
}

export function encryptAndPackZAssetUTXOMessage(
    secrets: ZAssetUTXOMessage,
    rootReadingPubKey: PublicKey,
): string {
    return encryptAndPackUTXOMessage(
        UTXOMessageType.ZAsset,
        [
            secrets.secretRandom,
            secrets.zAccountId,
            secrets.zAssetId,
            secrets.originNetworkId,
            secrets.targetNetworkId,
            secrets.originZoneId,
            secrets.targetZoneId,
        ],
        rootReadingPubKey,
    );
}

export function encryptAndPackZAccountUTXOMessage(
    secrets: ZAccountUTXOMessage,
    rootReadingPubKey: PublicKey,
): string {
    return encryptAndPackUTXOMessage(
        UTXOMessageType.ZAccount,
        [
            secrets.secretRandom,
            secrets.networkId,
            secrets.zoneId,
            secrets.nonce,
            secrets.expiryTime,
            secrets.amountZkp,
            secrets.amountPrp,
            secrets.totalAmountPerTimePeriod,
        ],
        rootReadingPubKey,
    );
}

export function extractCipherKeyAndIvFromPackedPoint(
    packedKey: ephemeralKeyPacked,
): {
    cipherKey: Buffer;
    iv: Buffer;
} {
    return {
        cipherKey: Buffer.from(packedKey).slice(0, 16),
        iv: Buffer.from(packedKey).slice(16, 32),
    };
}

function generateRandomPadding(length: number): string {
    return Array(length)
        .fill(0)
        .map(() => Math.round(Math.random()))
        .join('');
}

function encodeUTXOMessage(type: UTXOMessageType, values: bigint[]): string {
    const config = UTXO_MESSAGE_CONFIGS[type];

    config.fields.forEach((field, index) => {
        assertInBabyJubJubSubOrder(values[index], field);
        assertMaxBits(values[index], FIELD_BIT_LENGTHS[field], field);
    });

    let binaryString = config.fields.reduce((result, field, index) => {
        const binary = bigintToBinaryString(
            values[index],
            FIELD_BIT_LENGTHS[field],
        ).slice(2); // skip `0b` at the beginning
        return result + binary;
    }, '0b');

    // Append random padding to fill 16 byte block of AES-128-CBC
    const paddingLength = config.size * 8 - binaryString.length + 2; // '+2' because there's '0b' at head
    if (paddingLength > 0) {
        binaryString += generateRandomPadding(paddingLength);
    }

    return bigintToBytes(BigInt(binaryString), config.size);
}

function decodeUTXOMessage<T extends UTXOMessage>(
    encodedMessageBinary: string,
    fields: (keyof T)[],
): T {
    let cursor = 2; // Skip first 2 '0b'
    const decodedMessage: Partial<T> = {};

    fields.forEach(field => {
        const bitLength =
            FIELD_BIT_LENGTHS[field as keyof typeof FIELD_BIT_LENGTHS];
        const str = encodedMessageBinary.slice(cursor, (cursor += bitLength));
        decodedMessage[field as keyof T] = BigInt(`0b${str}`) as any;
    });

    return decodedMessage as T;
}

function decodeZAssetsUTXOMessage(cipherMsgBinary: string): ZAssetUTXOMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[UTXOMessageType.ZAsset]
            .fields as keyof typeof decodeZAssetsUTXOMessage,
    );
}

function decodeZAccountUTXOMessage(
    cipherMsgBinary: string,
): ZAccountUTXOMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[UTXOMessageType.ZAccount]
            .fields as keyof typeof decodeZAccountUTXOMessage,
    );
}

function encryptAndPackMessage(
    secretMsg: string,
    rootReadingPubKey: PublicKey,
    messageSize: number,
): string {
    const ephemeralRandom = generateRandomInBabyJubSubField();
    const ephemeralPubKey = generateEcdhSharedKey(
        ephemeralRandom,
        rootReadingPubKey,
    );
    const ephemeralPubKeyPacked = packPublicKey(ephemeralPubKey);
    const ephemeralSharedPubKey = derivePubKeyFromPrivKey(ephemeralRandom);
    const ephemeralSharedPubKeyPacked = packPublicKey(ephemeralSharedPubKey);
    const {cipherKey, iv} = extractCipherKeyAndIvFromPackedPoint(
        ephemeralPubKeyPacked,
    );

    const ciphertext = encryptPlainText(
        bigIntToUint8Array(BigInt(secretMsg), messageSize),
        cipherKey,
        iv,
    );

    const ephemeralSharedPubKeyPackedHex = bigintToBytes(
        uint8ArrayToBigInt(ephemeralSharedPubKeyPacked),
        PACKED_PUB_KEY_SIZE,
    ).slice(2);

    const dataHex = bigintToBytes(
        uint8ArrayToBigInt(ciphertext),
        messageSize,
    ).slice(2);

    return ephemeralSharedPubKeyPackedHex + dataHex;
}

function encryptAndPackUTXOMessage(
    type: UTXOMessageType,
    values: bigint[],
    rootReadingPubKey: PublicKey,
): string {
    const config = UTXO_MESSAGE_CONFIGS[type];
    const secretMsg = encodeUTXOMessage(type, values);
    return (
        config.msgType +
        encryptAndPackMessage(secretMsg, rootReadingPubKey, config.size)
    );
}

function unpackUTXOMessage(
    ciphertextMsg: string,
    type: UTXOMessageType,
): [Uint8Array, ICiphertext] {
    const {size, msgType} = UTXO_MESSAGE_CONFIGS[type];

    const messageType = ciphertextMsg.slice(0, MSG_TYPE_WIDTH);
    if (messageType != msgType) {
        throw new Error(
            `Message type must be equal to ${msgType} but got ${messageType}`,
        );
    }
    const ephemeralKeyPackedHex = ciphertextMsg.slice(
        MSG_TYPE_WIDTH,
        EPHEMERAL_KEY_WIDTH + MSG_TYPE_WIDTH,
    );
    const ephemeralKeyPacked = bigIntToUint8Array(
        BigInt(`0x${ephemeralKeyPackedHex}`),
        PACKED_PUB_KEY_SIZE,
    );

    const cipheredTextHex = ciphertextMsg.slice(
        EPHEMERAL_KEY_WIDTH + MSG_TYPE_WIDTH,
    );
    const cipheredText = bigIntToUint8Array(
        BigInt(`0x${cipheredTextHex}`),
        size,
    );

    return [ephemeralKeyPacked, cipheredText];
}

function unpackAndDecryptUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
    type: UTXOMessageType,
): UTXOMessage {
    const plaintextUInt8 = unpackAndDecrypt(
        message,
        rootReadingPrivateKey,
        type,
    );

    const secretRandomBin = bigintToBinaryString(
        BigInt(uint8ArrayToBigInt(plaintextUInt8)),
        UTXO_MESSAGE_CONFIGS[type].size * 8,
    );

    return type === 'ZAccount'
        ? decodeZAccountUTXOMessage(secretRandomBin)
        : decodeZAssetsUTXOMessage(secretRandomBin);
}

function unpackAndDecrypt(
    ciphertextMsg: string,
    rootReadingPrivateKey: PrivateKey,
    type: UTXOMessageType,
): Uint8Array {
    const [ephemeralKeyPacked, iCiphertext] = unpackUTXOMessage(
        ciphertextMsg,
        type,
    );
    const ephemeralKey = unpackPublicKey(ephemeralKeyPacked);

    const ephemeralSharedKey = generateEcdhSharedKey(
        rootReadingPrivateKey,
        ephemeralKey,
    );

    const {cipherKey, iv} = extractCipherKeyAndIvFromPackedPoint(
        packPublicKey(ephemeralSharedKey),
    );

    let plaintextUInt8;
    try {
        plaintextUInt8 = decryptCipherText(iCiphertext, cipherKey, iv);
    } catch (error) {
        throw new Error(`Failed to decrypt ${error}`);
    }

    return plaintextUInt8;
}

function validateFields(
    message: any,
    fields: (keyof typeof FIELD_ALLOWED_VALUES)[],
) {
    for (const field of fields) {
        if (message[field] > FIELD_ALLOWED_VALUES[field]) {
            throw new Error(`Failed to decrypt. Incorrect ${field}`);
        }
    }
}
