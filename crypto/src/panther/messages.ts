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
    CommitmentMessage,
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
    commitment: 256,
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

export enum UTXOMessageType {
    ZAccount = 'ZAccount',
    ZAssetPriv = 'ZAssetPriv',
    Commitment = 'Commitment',
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
    ZAssetPriv: {
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
    Commitment: {
        fields: ['commitment'],
        size: 32,
        msgType: '30',
    },
};

/**
 * Function to decrypt a message and unpack it into a ZAccountUTXOMessage
 * object.
 * @param {string} message - Represents the encrypted message string.
 * @param {PrivateKey} rootReadingPrivateKey - The root reading private key used
 * to decrypt the message.
 * @returns {ZAccountUTXOMessage} Returns a ZAccountUTXOMessage object.
 */
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

/**
 * Function to unpack and decrypt a message related to a ZAsset.
 * @param {string} message - Represents the encrypted message string.
 * @param {PrivateKey} rootReadingPrivateKey - The root reading private key used
 * to decrypt the message.
 * @returns {ZAssetUTXOMessage} Returns a ZAssetUTXOMessage object.
 */
export function unpackAndDecryptZAssetPrivUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
): ZAssetUTXOMessage {
    const zAssetMsg = unpackAndDecryptUTXOMessage(
        message,
        rootReadingPrivateKey,
        UTXOMessageType.ZAssetPriv,
    ) as ZAssetUTXOMessage;

    validateFields(zAssetMsg, [
        'originNetworkId',
        'targetNetworkId',
        'originZoneId',
        'targetZoneId',
    ]);

    return zAssetMsg;
}

/**
 * Unpacks and decrypts a commitment message.
 * @param {string} message - The commitment message to unpack and decrypt.
 * @param {PrivateKey} zAccountSecretRandom - The secret random for the
 * zAccount.
 * @param {PrivateKey} rootReadingPrivateKey - The root reading private key used
 * to decrypt the message.
 * @returns {CommitmentMessage} Returns an object with a decrypted commitment
 * message.
 */
export function unpackAndDecryptCommitmentMessage(
    message: string,
    zAccountSecretRandom: PrivateKey,
    rootReadingPrivateKey: PrivateKey,
): CommitmentMessage {
    const msg = unpackAndDecryptUTXOMessage(
        message,
        rootReadingPrivateKey,
        UTXOMessageType.Commitment,
    ) as CommitmentMessage;

    validateFields(msg, ['commitment']);

    return {
        commitment: msg.commitment ^ zAccountSecretRandom,
    };
}

/**
 * Function to encrypt and pack a ZAssetUTXOMessage object into a string.
 * @param {ZAssetUTXOMessage} secrets - The secrets object to be encrypted and
 * packed in the UTXO message.
 * @param {PublicKey} rootReadingPubKey - The root reading public key, used to
 * encrypt the UTXO message.
 * @returns {string} Returns the encrypted and packed UTXO message as a string.
 */
export function encryptAndPackZAssetPrivUTXOMessage(
    secrets: ZAssetUTXOMessage,
    rootReadingPubKey: PublicKey,
): string {
    validateFields(
        secrets,
        Object.keys(secrets) as (keyof ZAssetUTXOMessage)[],
    );

    return encryptAndPackUTXOMessage(
        UTXOMessageType.ZAssetPriv,
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

/**
 * Encrypts and packs a ZAccountUTXOMessage into a string.
 * @param {ZAccountUTXOMessage} secrets - The secrets object to be encrypted and
 * packed.
 * @param {PublicKey} rootReadingPubKey - The root reading public key, used to
 * encrypt the UTXO message.
 * @returns {string} Returns the encrypted and packed UTXO message as a string.
 */
export function encryptAndPackZAccountUTXOMessage(
    secrets: ZAccountUTXOMessage,
    rootReadingPubKey: PublicKey,
): string {
    validateFields(
        secrets,
        Object.keys(secrets) as (keyof ZAccountUTXOMessage)[],
    );

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

/**
 * Encrypts and packs a CommitmentMessage into a string.
 * @param {CommitmentMessage} secrets - The secrets object to be encrypted and
 * packed.
 * @param {PrivateKey} zAccountSecretRandom - The secret random for the
 * zAccount.
 * @param {PublicKey} rootReadingPubKey - The root reading public key, used to
 * encrypt the UTXO message.
 * @returns {string} Returns the encrypted and packed UTXO message as a string.
 */
export function encryptAndPackCommitmentMessage(
    secrets: CommitmentMessage,
    zAccountSecretRandom: PrivateKey,
    rootReadingPubKey: PublicKey,
): string {
    validateFields(
        secrets,
        Object.keys(secrets) as (keyof CommitmentMessage)[],
    );

    return encryptAndPackUTXOMessage(
        UTXOMessageType.Commitment,
        [secrets.commitment ^ zAccountSecretRandom],
        rootReadingPubKey,
    );
}

/**
 * Function to extract cipher key and iv from a packed key.
 * @param {ephemeralKeyPacked} packedKey - The ephemeralKeyPacked that contains
 * a cipher key and iv.
 * @returns {object} Returns an object with cipher key and iv.
 */
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

function decodeZAssetPrivUTXOMessage(
    cipherMsgBinary: string,
): ZAssetUTXOMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[UTXOMessageType.ZAssetPriv]
            .fields as keyof typeof decodeZAssetPrivUTXOMessage,
    );
}
function decodeUTXOCommitmentMessage(
    cipherMsgBinary: string,
): CommitmentMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[UTXOMessageType.Commitment]
            .fields as keyof typeof decodeUTXOCommitmentMessage,
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

// Define a mapping between UTXOMessageType and its corresponding decoder
// function. This allows us to dynamically call appropriate decoder function
// based on the UTXOMessageType.
const UtxoTypeToMessageDecoder: {
    [key in UTXOMessageType]: (
        bin: string,
    ) => ReturnType<typeof decodeUTXOMessage>;
} = {
    [UTXOMessageType.ZAccount]: decodeZAccountUTXOMessage,
    [UTXOMessageType.ZAssetPriv]: decodeZAssetPrivUTXOMessage,
    [UTXOMessageType.Commitment]: decodeUTXOCommitmentMessage,
};

function unpackAndDecryptUTXOMessage<T>(
    message: string,
    rootReadingPrivateKey: PrivateKey,
    type: UTXOMessageType,
): T {
    const plaintextUInt8 = unpackAndDecrypt(
        message,
        rootReadingPrivateKey,
        type,
    );

    const secretRandomBin = bigintToBinaryString(
        BigInt(uint8ArrayToBigInt(plaintextUInt8)),
        UTXO_MESSAGE_CONFIGS[type].size * 8,
    );

    const decoder = UtxoTypeToMessageDecoder[type];
    if (!decoder) throw new Error(`Unsupported message type: ${type}`);
    return decoder(secretRandomBin) as T;
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

    return decryptCipherText(iCiphertext, cipherKey, iv);
}

function validateFields(values: UTXOMessage, fields: (keyof UTXOMessage)[]) {
    for (const field of fields) {
        const value = values[field];
        if (value === undefined) {
            throw new Error(`Failed to decrypt. Incorrect ${field}`);
        }

        assertInBabyJubJubSubOrder(value, field);
        if (field in FIELD_ALLOWED_VALUES) {
            assertMaxBits(value, FIELD_BIT_LENGTHS[field], field);
        }
    }
}
