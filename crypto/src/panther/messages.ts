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
    PRIV_KEY_SIZE,
} from '../base/keypairs';
import {PublicKey, PrivateKey, ephemeralKeyPacked} from '../types/keypair';
import {DecryptedZAccountUTXOMessage, ICiphertext} from '../types/message';
import {assertInBabyJubJubSubOrder, assertMaxBits} from '../utils/assertions';
import {
    bigIntToUint8Array,
    uint8ArrayToBigInt,
    bigintToBytes32,
    bigintToBytes,
    bigintToBinaryString,
} from '../utils/bigint-conversions';

// sizes in bytes according to Message Encoding docs:
// https://docs.google.com/document/d/1XIlfyHXFXUUZVQNhV9glcLfUxiFOu8QAXkFhJMQc_3M
export const CIPHERTEXT_MSG_TYPE_V1_SIZE = 32;
export const CIPHERTEXT_MSG_TYPE_V6_SIZE = 64;

const Z_ACCOUNT_MSG_TYPE = '06';
const EPHEMERAL_KEY_WIDTH = PACKED_PUB_KEY_SIZE * 2;
const MSG_TYPE_WIDTH = 2;

// encryptAndPackMessageTypeV1 creates a message with encrypted secretRandom
// of the following format:
// msg = [IV, packedR, ...encrypted(prolog, r)]
export function encryptAndPackMessageTypeV1(
    secretRandom: bigint,
    rootReadingPubKey: PublicKey,
): string {
    const plaintext = bigintToBytes32(secretRandom);
    return encryptAndPackMessage(plaintext, rootReadingPubKey, PRIV_KEY_SIZE);
}

export function unpackAndDecryptMessageTypeV1(
    ciphertextMsg: string,
    rootReadingPrivateKey: PrivateKey,
): bigint {
    const plaintextUInt8 = unpackAndDecrypt(
        ciphertextMsg,
        rootReadingPrivateKey,
        unpackMessageTypeV1,
    );

    return uint8ArrayToBigInt(plaintextUInt8);
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

export function unpackMessageTypeV1(
    ciphertextMessageTypeV1: string,
): [Uint8Array, ICiphertext] {
    /*
    struct CiphertextMsg {
        EphemeralPublicKey, // 32 bytes (the packed form)
        EncryptedText // 32 bytes
    } // 64 bytes

    see: NewCommitments docs:
    https://docs.google.com/document/d/11oY8TZRPORDP3p5emL09pYKIAQTadNhVPIyZDtMGV8k/edit#bookmark=id.vxygmc6485de
    */
    // sizes in Hex string:
    const ephemeralKeyWidth = PACKED_PUB_KEY_SIZE * 2;
    const ciphertextWidth = CIPHERTEXT_MSG_TYPE_V1_SIZE * 2;

    if (ciphertextMessageTypeV1.length != ephemeralKeyWidth + ciphertextWidth) {
        throw `Message must be equal to ${ephemeralKeyWidth + ciphertextWidth}`;
    }

    const ephemeralKeyPackedHex = ciphertextMessageTypeV1.slice(
        0,
        ephemeralKeyWidth,
    );
    const ephemeralKeyPacked = bigIntToUint8Array(
        BigInt(`0x${ephemeralKeyPackedHex}`),
        PACKED_PUB_KEY_SIZE,
    );

    const cipheredTextHex = ciphertextMessageTypeV1.slice(ephemeralKeyWidth);
    const cipheredText = bigIntToUint8Array(
        BigInt(`0x${cipheredTextHex}`),
        CIPHERTEXT_MSG_TYPE_V1_SIZE,
    );

    return [ephemeralKeyPacked, cipheredText];
}

// ### preimage of cipherMsg  // 512 bit
// secretRandom;              // 256 bit
// networkId;                 // 6 bit
// zoneId;                    // 16 bit
// nonce;                     // 16 bit
// expiryTime;                // 32 bit
// amountZkp;                 // 64 bit
// amountPrp;                 // 58 bit
// totalAmountPerTimePeriod;  // 64 bit
export function encodeZAccountUTXOMessage(
    secretRandom: bigint,
    networkId: bigint,
    zoneId: bigint,
    nonce: bigint,
    expiryTime: bigint,
    amountZkp: bigint,
    amountPrp: bigint,
    totalAmountPerTimePeriod: bigint,
): string {
    assertInBabyJubJubSubOrder(secretRandom, 'secretRandom');
    assertMaxBits(networkId, 6, 'networkId');
    assertMaxBits(zoneId, 16, 'zoneId');
    assertMaxBits(nonce, 16, 'nonce');
    assertMaxBits(expiryTime, 32, 'expiryTime');
    assertMaxBits(amountZkp, 64, 'amountZkp');
    assertMaxBits(amountPrp, 58, 'amountPrp');
    assertMaxBits(totalAmountPerTimePeriod, 64, 'totalAmountPerTimePeriod');

    return bigintToBytes(
        BigInt(
            '0b' +
                bigintToBinaryString(secretRandom, 256).slice(2) +
                bigintToBinaryString(networkId, 6).slice(2) +
                bigintToBinaryString(zoneId, 16).slice(2) +
                bigintToBinaryString(nonce, 16).slice(2) +
                bigintToBinaryString(expiryTime, 32).slice(2) +
                bigintToBinaryString(amountZkp, 64).slice(2) +
                bigintToBinaryString(amountPrp, 58).slice(2) +
                bigintToBinaryString(totalAmountPerTimePeriod, 64).slice(2),
        ),
        CIPHERTEXT_MSG_TYPE_V6_SIZE,
    );
}

export function decodeZAccountUTXOMessage(plaintextBinary: string): {
    secretRandom: bigint;
    networkId: bigint;
    zoneId: bigint;
    nonce: bigint;
    expiryTime: bigint;
    amountZkp: bigint;
    amountPrp: bigint;
    totalAmountPerTimePeriod: bigint;
} {
    const secretRandomBin = plaintextBinary.slice(2, 258);
    const networkIdBin = plaintextBinary.slice(258, 264);
    const zoneIdBin = plaintextBinary.slice(264, 280);
    const nonceBin = plaintextBinary.slice(280, 296);
    const expiryTimeBin = plaintextBinary.slice(296, 328);
    const amountZkpBin = plaintextBinary.slice(328, 392);
    const amountPrpBin = plaintextBinary.slice(392, 450);
    const totalAmountPerTimePeriodBin = plaintextBinary.slice(450, 514);

    return {
        secretRandom: BigInt(`0b${secretRandomBin}`),
        networkId: BigInt(`0b${networkIdBin}`),
        zoneId: BigInt(`0b${zoneIdBin}`),
        nonce: BigInt(`0b${nonceBin}`),
        expiryTime: BigInt(`0b${expiryTimeBin}`),
        amountZkp: BigInt(`0b${amountZkpBin}`),
        amountPrp: BigInt(`0b${amountPrpBin}`),
        totalAmountPerTimePeriod: BigInt(`0b${totalAmountPerTimePeriodBin}`),
    };
}

function encryptAndPackMessage(
    plaintext: string,
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
        bigIntToUint8Array(BigInt(plaintext), messageSize),
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

// for zAccount UTXO secret message
// struct message {
//     byte msgType,
//     bytes[32] ephemeralKey;
//     bytes[64] cipherMsg
// }
// ### preimage of cipherMsg  // 512 bit
// secretRandom;              // 256 bit
// networkId;                 // 6 bit
// zoneId;                    // 16 bit
// nonce;                     // 16 bit
// expiryTime;                // 32 bit
// amountZkp;                 // 64 bit
// amountPrp;                 // 40 bit
// totalAmountPerTimePeriod;  // 64 bit
export function encryptAndPackZAccountUTXOMessage(
    secretRandom: bigint,
    networkId: bigint,
    zoneId: bigint,
    nonce: bigint,
    expiryTime: bigint,
    amountZkp: bigint,
    amountPrp: bigint,
    totalAmountPerTimePeriod: bigint,
    rootReadingPubKey: PublicKey,
): string {
    const plaintext = encodeZAccountUTXOMessage(
        secretRandom,
        networkId,
        zoneId,
        nonce,
        expiryTime,
        amountZkp,
        amountPrp,
        totalAmountPerTimePeriod,
    );

    const message =
        Z_ACCOUNT_MSG_TYPE +
        encryptAndPackMessage(
            plaintext,
            rootReadingPubKey,
            CIPHERTEXT_MSG_TYPE_V6_SIZE,
        );

    return message;
}

export function unpackZAccountUTXOMessage(
    cipherMsgZAccountUtxo: string,
): [Uint8Array, ICiphertext] {
    const messageType = cipherMsgZAccountUtxo.slice(0, MSG_TYPE_WIDTH);
    if (messageType != Z_ACCOUNT_MSG_TYPE) {
        throw `Message type must be equal to ${Z_ACCOUNT_MSG_TYPE} but got ${messageType}`;
    }
    const ephemeralKeyPackedHex = cipherMsgZAccountUtxo.slice(
        MSG_TYPE_WIDTH,
        EPHEMERAL_KEY_WIDTH + MSG_TYPE_WIDTH,
    );
    const ephemeralKeyPacked = bigIntToUint8Array(
        BigInt(`0x${ephemeralKeyPackedHex}`),
        PACKED_PUB_KEY_SIZE,
    );

    const cipheredTextHex = cipherMsgZAccountUtxo.slice(
        EPHEMERAL_KEY_WIDTH + MSG_TYPE_WIDTH,
    );
    const cipheredText = bigIntToUint8Array(
        BigInt(`0x${cipheredTextHex}`),
        CIPHERTEXT_MSG_TYPE_V6_SIZE,
    );

    return [ephemeralKeyPacked, cipheredText];
}

export function unpackAndDecryptZAccountUTXOMessage(
    message: string,
    rootReadingPrivateKey: PrivateKey,
): DecryptedZAccountUTXOMessage {
    const plaintextUInt8 = unpackAndDecrypt(
        message,
        rootReadingPrivateKey,
        unpackZAccountUTXOMessage,
    );

    const secretRandomBin = bigintToBinaryString(
        BigInt(uint8ArrayToBigInt(plaintextUInt8)),
        512,
    );

    const {
        secretRandom,
        networkId,
        zoneId,
        nonce,
        expiryTime,
        amountZkp,
        amountPrp,
        totalAmountPerTimePeriod,
    } = decodeZAccountUTXOMessage(secretRandomBin);

    // additional checks to make sure that values have correct range
    // TODO: extract these checks in separate assert functions
    if (networkId > 2n) {
        throw new Error('Failed to get secret random. Incorrect networkId');
    }

    if (zoneId > 1n) {
        throw new Error('Failed to get secret random. Incorrect zoneId');
    }

    return {
        secretRandom,
        networkId,
        zoneId,
        nonce,
        expiryTime,
        amountZkp,
        amountPrp,
        totalAmountPerTimePeriod,
    };
}

function unpackAndDecrypt(
    ciphertextMsg: string,
    rootReadingPrivateKey: PrivateKey,
    unpackFunction: (ciphertextMsg: string) => [Uint8Array, ICiphertext],
): Uint8Array {
    const [ephemeralKeyPacked, iCiphertext] = unpackFunction(ciphertextMsg);
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
        throw new Error(`Failed to decrypt secret random ${error}`);
    }

    // check if first 5 most significant bits are zeros
    if ((plaintextUInt8[0] & 0xf8) != 0x00) {
        throw new Error('Failed to get secret random. Incorrect padding');
    }

    return plaintextUInt8;
}
