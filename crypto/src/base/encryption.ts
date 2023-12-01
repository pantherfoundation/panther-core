// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// The code is inspired by applied ZKP
import crypto from 'crypto';

import {babyjub} from 'circomlibjs';
import {mulPointEscalar} from 'circomlibjs/src/babyjub';

import {PrivateKey, PublicKey, EcdhSharedKey, Point} from '../types/keypair';
import {ICiphertext} from '../types/message';
import {assertInBabyJubJubSubOrder} from '../utils/assertions';

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

/**
 * This function encrypts a point using an El Gamal algorithm.
 *
 * @param {Point} originalPoint - The original point to encrypt.
 * @param {PublicKey} publicKey - The public key used for encryption.
 * @param {bigint} sessionKey - The session key used for encryption.
 * @returns {Point} - The encrypted point resulting from the El Gamal
 * encryption.
 *
 * @throws {Error} Will throw an error if the sessionKey is not in the Baby
 * JubJub sub-order.
 */
export function encryptPointElGamal(
    originalPoint: Point,
    publicKey: PublicKey,
    sessionKey: bigint,
): Point {
    assertInBabyJubJubSubOrder(sessionKey, 'sessionKey');
    const maskingPoint = mulPointEscalar(publicKey, sessionKey);
    return babyjub.addPoint(originalPoint, maskingPoint) as Point;
}

/**
 * This function decrypts a point using the El Gamal algorithm.
 *
 * @param {Point} encryptedPoint - The encrypted point to be decrypted.
 * @param {PrivateKey} privateKey - The private key used for decryption.
 * @param {PublicKey} ephemeralPublicKey - The ephemeral public key used for
 * decryption.
 * @returns {Point} - The decrypted point resulting from the El Gamal
 * decryption.
 */
export function decryptPointElGamal(
    encryptedPoint: Point,
    privateKey: PrivateKey,
    ephemeralPublicKey: PublicKey,
): Point {
    const unmaskingPoint = mulPointEscalar(ephemeralPublicKey, privateKey);
    const negatedUnmaskingPoint = [
        babyjub.p - unmaskingPoint[0],
        unmaskingPoint[1],
    ];
    return babyjub.addPoint(encryptedPoint, negatedUnmaskingPoint) as Point;
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
    ephemeralPublicKey: PublicKey;
} {
    const sessionKey = generateRandomInBabyJubSubField();
    const ephemeralPublicKey = mulPointEscalar(
        babyjub.Base8,
        sessionKey,
    ) as PublicKey;
    const encryptedPoints = originalPoints.map(point =>
        encryptPointElGamal(point, publicKey, sessionKey),
    );
    return {
        encryptedPoints,
        ephemeralPublicKey,
    };
}
