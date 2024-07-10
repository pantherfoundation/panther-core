// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {describe, expect} from '@jest/globals';
import {babyjub} from 'circomlibjs';
import {mulPointEscalar} from 'circomlibjs/src/babyjub';

import {
    generateEcdhSharedKey,
    encryptPlainText,
    decryptCipherText,
    unmaskPoint,
    maskPoint,
    ephemeralPublicKeyBuilder,
} from '../../src/base/encryption';
import {generateRandomInBabyJubSubField} from '../../src/base/field-operations';
import {generateRandomKeypair, packPublicKey} from '../../src/base/keypairs';
import {extractCipherKeyAndIvFromPackedPoint} from '../../src/panther/messages';
import {Keypair, Point, PublicKey} from '../../src/types/keypair';
import {
    bigIntToUint8Array,
    uint8ArrayToBigInt,
} from '../../src/utils/bigint-conversions';

import ephemeralPublicKeyBuilderData from './data/ephemeralPublicKeyBuilder';

function generateKeysAndEncryptedText(
    keypair1: Keypair,
    keypair2: Keypair,
    plaintext: bigint,
): Uint8Array {
    const ecdhSharedKey12 = generateEcdhSharedKey(
        keypair1.privateKey,
        keypair2.publicKey,
    );
    const extractCipherKeysFromEcdh12 = extractCipherKeyAndIvFromPackedPoint(
        packPublicKey(ecdhSharedKey12),
    );

    return encryptPlainText(
        bigIntToUint8Array(plaintext),
        extractCipherKeysFromEcdh12.cipherKey,
        extractCipherKeysFromEcdh12.iv,
    );
}

function decryptCiphertext(
    ciphertext: Uint8Array,
    keypair1: Keypair,
    keypair2: Keypair,
): bigint {
    const ecdhSharedKey21 = generateEcdhSharedKey(
        keypair2.privateKey,
        keypair1.publicKey,
    );
    const extractCipherKeysFromEcdh21 = extractCipherKeyAndIvFromPackedPoint(
        packPublicKey(ecdhSharedKey21),
    );

    return uint8ArrayToBigInt(
        decryptCipherText(
            ciphertext,
            extractCipherKeysFromEcdh21.cipherKey,
            extractCipherKeysFromEcdh21.iv,
        ),
    );
}

function generateSecretPoint(): Point {
    const secret = generateRandomInBabyJubSubField();
    return mulPointEscalar(babyjub.Base8, secret) as Point;
}

describe('Encryption Test Suite', () => {
    describe('AES-128-CBC', () => {
        let keypair1: Keypair;
        let keypair2: Keypair;
        let plaintext: bigint;
        let ciphertext: Uint8Array;
        let decryptedCiphertext: bigint;

        beforeEach(() => {
            keypair1 = generateRandomKeypair();
            keypair2 = generateRandomKeypair();
            plaintext = generateRandomKeypair().privateKey;
            ciphertext = generateKeysAndEncryptedText(
                keypair1,
                keypair2,
                plaintext,
            );
            decryptedCiphertext = decryptCiphertext(
                ciphertext,
                keypair1,
                keypair2,
            );
        });

        it('Ciphertext should differ from the plaintext', () => {
            expect(bigIntToUint8Array(plaintext) !== ciphertext).toBe(true);
        });

        it('Ciphertext should have 32 bytes of data', () => {
            expect(ciphertext.length).toEqual(32);
        });

        it('The decrypted ciphertext should be correct', () => {
            expect(decryptedCiphertext.toString()).toEqual(
                plaintext.toString(),
            );
        });
    });

    describe('El Gamal', () => {
        let secretPoint: Point;
        let keypair: Keypair;

        beforeEach(() => {
            secretPoint = generateSecretPoint();
            keypair = generateRandomKeypair();
        });

        it('masks and unmasks single point', () => {
            const encryptedPoint = maskPoint(secretPoint, keypair.publicKey);
            const decryptedPoint = unmaskPoint(
                encryptedPoint,
                keypair.publicKey,
            );

            expect(secretPoint).toEqual(decryptedPoint);
        });

        it('#ephemeralPublicKeyBuilder', () => {
            const keys = ephemeralPublicKeyBuilder(
                ephemeralPublicKeyBuilderData.ephemeralRandom,
                ephemeralPublicKeyBuilderData.pubKey as PublicKey,
                10,
            );
            expect(keys.ephemeralPubKeys.length).toEqual(10);
            expect(keys.sharedPubKeys.length).toEqual(10);

            expect(keys.ephemeralPubKeys).toEqual(
                ephemeralPublicKeyBuilderData.ephemeralPubKey,
            );
            expect(keys.sharedPubKeys).toEqual(
                ephemeralPublicKeyBuilderData.sharedPubKey,
            );
        });
    });
});
