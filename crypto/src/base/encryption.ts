// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// The code is inspired by applied ZKP
import crypto from 'crypto';

import {babyjub} from 'circomlibjs';
import {mulPointEscalar} from 'circomlibjs/src/babyjub';
import poseidon from 'circomlibjs/src/poseidon';

import {
    PrivateKey,
    PublicKey,
    EcdhSharedKey,
    Point,
    Keypair,
} from '../types/keypair';
import {ICiphertext} from '../types/message';

import {generateRandomInBabyJubSubField} from './field-operations';

export function generateEcdhSharedKey(
    privateKey: PrivateKey,
    publicKey: PublicKey,
): EcdhSharedKey {
    return babyjub.mulPointEscalar(publicKey, privateKey) as EcdhSharedKey;
}

export function encryptPlainText(
    plaintext: Uint8Array,
    cipherKey: Uint8Array,
    iv: Uint8Array,
): ICiphertext {
    try {
        const cipher = crypto.createCipheriv('aes-128-cbc', cipherKey, iv);
        cipher.setAutoPadding(false);
        const cipheredText1 = cipher.update(plaintext);
        const cipheredText2 = cipher.final();
        return new Uint8Array([...cipheredText1, ...cipheredText2]);
    } catch (error) {
        throw Error(`Failed to encrypt message: ${error}`);
    }
}

export function decryptCipherText(
    ciphertext: ICiphertext,
    cipherKey: Uint8Array,
    iv: Uint8Array,
): Uint8Array {
    const decipher = crypto.createDecipheriv('aes-128-cbc', cipherKey, iv);
    decipher.setAutoPadding(false);

    return new Uint8Array([
        ...decipher.update(ciphertext),
        ...decipher.final(),
    ]);
}

/*
"El Gamal Public Key Encryption with Elliptic Curve Cryptography

1. Encryption: To encrypt a point 'originalPoint',
    - Randomly generate an integer shared session 'sessionKey' in babyJubJub
      suborder.
    - Compute 'ephemeralPublicKey' using the formula: ephemeralPublicKey =
      mulPointEscalar(babyjub.Base8, sessionKey).
    - Compute 'maskingPoint' using the formula: maskingPoint =
      mulPointEscalar(publicKey, sessionKey).
    - Compute 'encryptedPoint', the final ciphertext pair using the formula:
      encryptedPoint = babyjub.addPoint(originalPoint, maskingPoint).

2. Decryption: To decrypt the point 'encryptedPoint', follow these steps:
    - Compute 'unmaskingPoint' using the formula: unmaskingPoint =
      mulPointEscalar(ephemeralPublicKey, privateKey), where
      'ephemeralPublicKey' is the shared ephemeral key generated during
      encryption and 'privateKey' is the receiver private key.
    - Negate the X coordinate of 'unmaskingPoint', which results
      'negatedUnmaskingPoint'.
    - Compute 'decryptedPoint', the original point, using the formula:
      decryptedPoint = babyjub.addPoint(encryptedPoint, negatedUnmaskingPoint).

*/

export function maskPoint(originalPoint: Point, maskingPoint: Point): Point {
    return babyjub.addPoint(originalPoint, maskingPoint) as Point;
}

export function unmaskPoint(encryptedPoint: Point, maskingPoint: Point): Point {
    const negatedMaskingPoint = [babyjub.p - maskingPoint[0], maskingPoint[1]];
    return babyjub.addPoint(encryptedPoint, negatedMaskingPoint) as Point;
}

/**
 * This function encrypts an array of points using the El Gamal algorithm.
 *
 * @param {Point[]} originalPoints - The array of points to encrypt.
 * @param {PublicKey} publicKey - The public key used for encryption.
 * @returns {Point[]} encryptedPoints - The array of encrypted points.
 * @returns {PublicKey} ephemeralPublicKey - The ephemeral public key used for
 * encryption.
 */
export function encryptPointsElGamal(
    originalPoints: Point[],
    publicKey: PublicKey,
): {
    encryptedPoints: Point[];
    ephemeralKeypair: Keypair;
} {
    // Generate a ephemeral random - session key
    const ephemeralRandom = generateRandomInBabyJubSubField();
    // Derive the ephemeral keypair from the session key
    const ephemeralKeys = ephemeralPublicKeyBuilder(
        ephemeralRandom,
        publicKey,
        originalPoints.length,
    );

    const encryptedPoints = originalPoints.map((point, idx) =>
        maskPoint(point, ephemeralKeys.sharedPubKeys[idx] as Point),
    );

    return {
        encryptedPoints,
        ephemeralKeypair: {
            privateKey: ephemeralRandom,
            publicKey: ephemeralKeys.ephemeralPubKeys[0],
        },
    };
}

/**
 * Generates arrays of ephemeral and shared public keys.
 * @param ephemeralRandom - The initial random value for generating ephemeral keys.
 * @param publicKey - The public key used for generating shared keys.
 * @param length - The number of keys to generate.
 * @returns An object containing arrays of ephemeral and shared public keys.
 */
export function ephemeralPublicKeyBuilder(
    ephemeralRandom: bigint,
    publicKey: PublicKey,
    length: number,
): {
    ephemeralPubKeys: PublicKey[];
    sharedPubKeys: PublicKey[];
} {
    const ephemeralPubKeys: PublicKey[] = [];
    const sharedPubKeys: PublicKey[] = [];

    // Helper function to generate a new ephemeral random value
    const generateNewEphemeralRandom = (sharedPubKey: PublicKey): bigint => {
        return BigInt(
            '0b' +
                poseidon([sharedPubKey[0], sharedPubKey[1]])
                    .toString(2)
                    .padStart(252, '0')
                    .slice(-252),
        );
    };

    // Iterate to generate the required number of keys
    for (let i = 0; i < length; i++) {
        // Generate ephemeral public key
        const ephemeralPubKey = mulPointEscalar(
            babyjub.Base8,
            ephemeralRandom,
        ) as PublicKey;
        ephemeralPubKeys.push(ephemeralPubKey);

        // Generate shared public key
        const sharedPubKey = mulPointEscalar(
            publicKey,
            ephemeralRandom,
        ) as PublicKey;
        sharedPubKeys.push(sharedPubKey);

        // Update ephemeralRandom for the next iteration
        ephemeralRandom = generateNewEphemeralRandom(sharedPubKey);
    }

    return {ephemeralPubKeys, sharedPubKeys};
}
