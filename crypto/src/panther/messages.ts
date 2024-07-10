// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

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
    SpentUTXOMessage,
    Message,
    ZAccountUTXOMessage,
    ZAssetPrivUTXOMessage,
    ZAssetUTXOMessage,
    PrivateMessage,
    MessageType,
} from '../types/message';
import {assert, assertMaxBits} from '../utils/assertions';
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
    spentUtxoCommitment1: 256,
    spentUtxoCommitment2: 256,
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
    scaledAmount: 64,
    totalAmountPerTimePeriod: 64,
} as const;

const ALLOWED_MAX_VALUES: {[key in keyof Message]: bigint} = {
    zoneId: 2n,
    originZoneId: 1n,
    targetZoneId: 1n,
    networkId: 2n,
    originNetworkId: 2n,
    targetNetworkId: 2n,
} as const;

type MessageConfig = {
    [key in MessageType]: {
        fields: Array<keyof Message>;
        size: number;
        msgType: string;
    };
};

export const UTXO_MESSAGE_CONFIGS: MessageConfig = {
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
    ZAsset: {
        fields: [
            'secretRandom',
            'zAccountId',
            'zAssetId',
            'originNetworkId',
            'targetNetworkId',
            'originZoneId',
            'targetZoneId',
            'scaledAmount',
        ],
        size: 64, // actual size is 452 bits but we need to round up to the nearest byte that is a multiple of 16 because of AES-128-CBC
        msgType: '08',
    },
    SpentUTXO: {
        fields: ['spentUtxoCommitment1', 'spentUtxoCommitment2'],
        size: 64,
        msgType: '09',
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
    return unpackDecryptAndValidateMessage(
        message,
        rootReadingPrivateKey,
        MessageType.ZAccount,
    );
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
): ZAssetPrivUTXOMessage {
    return unpackDecryptAndValidateMessage(
        message,
        rootReadingPrivateKey,
        MessageType.ZAssetPriv,
    );
}

/**
 * Function to unpack and decrypt a message associated to a ZAsset.
 * @param {string} message - Represents the encrypted message string.
 * @param {PrivateKey} rootReadingPrivateKey - The root reading private key used
 * to decrypt the message.
 * @returns {ZAssetUTXOMessage} Returns a ZAssetUTXOMessage object.
 */
export function unpackAndDecryptZAssetUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
): ZAssetUTXOMessage {
    return unpackDecryptAndValidateMessage(
        message,
        rootReadingPrivateKey,
        MessageType.ZAsset,
    );
}

/**
 * Unpacks and decrypts a Spent UTXO message.
 * @param {string} message - The Spent UTXO message to unpack and decrypt.
 * @param {PrivateKey} rootReadingPrivateKey - The root reading private key used
 * to decrypt the message.
 * @param {PrivateKey} zAccountSecretRandom - The secret random for the
 * zAccount.
 * @returns {SpentUTXOMessage} Returns an object with a decrypted Spent UTXO
 * message.
 */
export function unpackAndDecryptSpentUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
    zAccountSecretRandom: PrivateKey,
): SpentUTXOMessage {
    return unpackDecryptAndValidateMessage(
        message,
        rootReadingPrivateKey,
        MessageType.SpentUTXO,
        zAccountSecretRandom,
    );
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
    secrets: ZAssetPrivUTXOMessage,
    rootReadingPubKey: PublicKey,
): string {
    return validateEncryptAndPackMessage(
        secrets,
        rootReadingPubKey,
        MessageType.ZAssetPriv,
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
export function encryptAndPackZAssetUTXOMessage(
    secrets: ZAssetUTXOMessage,
    rootReadingPubKey: PublicKey,
): string {
    return validateEncryptAndPackMessage(
        secrets,
        rootReadingPubKey,
        MessageType.ZAsset,
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
    return validateEncryptAndPackMessage(
        secrets,
        rootReadingPubKey,
        MessageType.ZAccount,
    );
}

/**
 * Encrypts and packs a SpentUTXOMessage into a string.
 * @param {SpentUTXOMessage} secrets - The secrets object to be encrypted and
 * packed.
 * @param {PublicKey} rootReadingPubKey - The root reading public key, used to
 * encrypt the UTXO message.
 * @param {PrivateKey} zAccountSecretRandom - The secret random for the
 * zAccount.
 * @returns {string} Returns the encrypted and packed UTXO message as a string.
 */
export function encryptAndPackSpentUTXOMessage(
    secrets: SpentUTXOMessage,
    rootReadingPubKey: PublicKey,
    zAccountSecretRandom: PrivateKey,
): string {
    return validateEncryptAndPackMessage(
        secrets,
        rootReadingPubKey,
        MessageType.SpentUTXO,
        zAccountSecretRandom,
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

/**
 * Function to unpack, decrypt and validate UTXO message.
 *
 * @param message - The message to be decrypted and validated.
 * @param rootReadingPrivateKey - The private key for decryption.
 * @param messageType - The type of the UTXO message.
 * @param zAccountSecretRandom - The optional private key for Spent UTXO message
 * type.
 *
 * @returns The decrypted and validated UTXO message.
 */
function unpackDecryptAndValidateMessage<T extends PrivateMessage>(
    message: string,
    rootReadingPrivateKey: PrivateKey,
    messageType: MessageType,
    zAccountSecretRandom?: PrivateKey,
): T {
    let utxoMsg = unpackAndDecryptUTXOMessage(
        message,
        rootReadingPrivateKey,
        messageType,
    ) as T;

    // Special handling for SpentUTXOMessage type
    if (messageType === MessageType.SpentUTXO && zAccountSecretRandom) {
        const spentUTXOMessage = utxoMsg as SpentUTXOMessage;

        utxoMsg = {
            spentUtxoCommitment1:
                spentUTXOMessage.spentUtxoCommitment1 ^ zAccountSecretRandom,
            spentUtxoCommitment2:
                spentUTXOMessage.spentUtxoCommitment2 ^ zAccountSecretRandom,
        } as T;
    } else {
        // Please note, there's no need to validate the messages of the
        // SpentUTXOMessage type. These messages aren't circulated within the
        // circuits, hence, they don't need to be in BN254 fields.
        validateFields(utxoMsg, UTXO_MESSAGE_CONFIGS[messageType].fields);
    }

    return utxoMsg as T;
}

/**
 * Function to validate, encrypt and pack UTXO messages
 * @param secrets - UTXO message secrets
 * @param rootReadingPubKey - Public key for root reading
 * @param messageType - Type of the UTXO message
 * @param zAccountSecretRandom - Optional private key for commitment message
 * @returns - Encrypted and packed UTXO message
 */
function validateEncryptAndPackMessage<T extends Message>(
    secrets: T,
    rootReadingPubKey: PublicKey,
    messageType: MessageType,
    zAccountSecretRandom?: PrivateKey,
): string {
    let values: bigint[] = [];
    // If the message type is SpentUTXO and zAccountSecretRandom is provided
    // Set values to the XOR of the commitments and zAccountSecretRandom
    // Else map the secrets to the corresponding fields of the message type
    if (messageType === MessageType.SpentUTXO && zAccountSecretRandom) {
        const spentUTXOMessage = secrets as SpentUTXOMessage;
        values = [
            spentUTXOMessage.spentUtxoCommitment1 ^ zAccountSecretRandom,
            spentUTXOMessage.spentUtxoCommitment2 ^ zAccountSecretRandom,
        ];
    } else {
        // Please note, there's no need to validate the messages of the
        // SpentUTXOMessage type. These messages aren't circulated within the
        // circuits, hence, they don't need to be in BN254 fields.
        validateFields(secrets, UTXO_MESSAGE_CONFIGS[messageType].fields);

        const fields = UTXO_MESSAGE_CONFIGS[messageType].fields;
        values = fields.map(field => secrets[field]) as bigint[];
    }

    return encryptAndPackUTXOMessage(messageType, values, rootReadingPubKey);
}

function generateRandomPadding(length: number): string {
    return Array(length)
        .fill(0)
        .map(() => Math.round(Math.random()))
        .join('');
}

function encodeUTXOMessage(type: MessageType, values: bigint[]): string {
    const config = UTXO_MESSAGE_CONFIGS[type];

    config.fields.forEach((field, index) => {
        assertMaxBits(values[index], FIELD_BIT_LENGTHS[field], field);
        const maxAllowedValue = ALLOWED_MAX_VALUES[field];
        if (maxAllowedValue) {
            assert(values[index] <= maxAllowedValue, `Invalid ${field}`);
        }
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

function decodeUTXOMessage<T extends PrivateMessage>(
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
        UTXO_MESSAGE_CONFIGS[MessageType.ZAssetPriv]
            .fields as keyof typeof decodeZAssetPrivUTXOMessage,
    );
}

function decodeZAssetsUTXOMessage(
    cipherMsgBinary: string,
): ZAssetPrivUTXOMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[MessageType.ZAsset]
            .fields as keyof typeof decodeZAssetsUTXOMessage,
    );
}

function decodeSpentUTXOMessage(cipherMsgBinary: string): SpentUTXOMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[MessageType.SpentUTXO]
            .fields as keyof typeof decodeSpentUTXOMessage,
    );
}

function decodeZAccountUTXOMessage(
    cipherMsgBinary: string,
): ZAccountUTXOMessage {
    return decodeUTXOMessage(
        cipherMsgBinary,
        UTXO_MESSAGE_CONFIGS[MessageType.ZAccount]
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
    type: MessageType,
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
    type: MessageType,
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
    [key in MessageType]: (bin: string) => PrivateMessage;
} = {
    [MessageType.ZAccount]: decodeZAccountUTXOMessage,
    [MessageType.ZAsset]: decodeZAssetsUTXOMessage,
    [MessageType.ZAssetPriv]: decodeZAssetPrivUTXOMessage,
    [MessageType.SpentUTXO]: decodeSpentUTXOMessage,
};

function unpackAndDecryptUTXOMessage<T>(
    message: string,
    rootReadingPrivateKey: PrivateKey,
    type: MessageType,
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
    type: MessageType,
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

function validateFields(values: Message, fields: Array<keyof Message>) {
    for (const field of fields) {
        const value = values[field];
        if (value === undefined) {
            throw new Error(`Failed to decrypt. Incorrect ${field}`);
        }

        assertMaxBits(value, FIELD_BIT_LENGTHS[field], field);
        if (field in ALLOWED_MAX_VALUES) {
            const maxAllowedValue = ALLOWED_MAX_VALUES[field];
            if (maxAllowedValue) {
                assert(value <= maxAllowedValue, `Invalid ${field}`);
            }
        }
    }
}
