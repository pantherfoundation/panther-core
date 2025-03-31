// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {describe, expect} from '@jest/globals';

import {
    generateEcdhSharedKey,
    encryptPlainText,
    decryptCipherText,
} from '../../src/base/encryption';
import {generateRandomKeypair, packPublicKey} from '../../src/base/keypairs';
import {extractCipherKeyAndIvFromPackedPoint} from '../../src/panther/messages';
import {Keypair} from '../../src/types/keypair';
import {
    bigIntToUint8Array,
    uint8ArrayToBigInt,
} from '../../src/utils/bigint-conversions';

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
});
