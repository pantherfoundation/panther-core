// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {poseidon} from 'circomlibjs';
import {ethers} from 'ethers';

import {
    encryptPlainText,
    generateEcdhSharedKey,
    decryptCipherText,
} from '../../src/base/encryption';
import {generateRandomKeypair, packPublicKey} from '../../src/base/keypairs';
import {deriveKeypair} from '../../src/panther/keys';
import {extractCipherKeyAndIvFromPackedPoint} from '../../src/panther/messages';
import {Keypair} from '../../src/types/keypair';
import {bigIntToUint8Array} from '../../src/utils/bigint-conversions';

describe('Message encryption and decryption', () => {
    it('expect decrypt message to be equal initial plain message', async () => {
        const signer = ethers.Wallet.createRandom();

        const signature = await signer.signMessage('some message');

        const readingKeypair: Keypair = deriveKeypair(poseidon([signature]), 1);
        // spending keypair(R,r)
        const childRandomKeypair = generateRandomKeypair();

        // generates by sender ECDH(rootReadingPubKey, r)
        const spendingEcdhSharedKey = generateEcdhSharedKey(
            childRandomKeypair.privateKey,
            readingKeypair.publicKey,
        );

        // generates by recipient ECDH(R, rootReadingPrivKey)
        const readingEcdhSharedKey = generateEcdhSharedKey(
            readingKeypair.privateKey,
            childRandomKeypair.publicKey,
        );

        const secretRandom = childRandomKeypair.privateKey;

        const {iv: ivSpending, cipherKey: ckSpending} =
            extractCipherKeyAndIvFromPackedPoint(
                packPublicKey(spendingEcdhSharedKey),
            );

        const ciphertext = encryptPlainText(
            bigIntToUint8Array(secretRandom, 32),
            ckSpending,
            ivSpending,
        );

        const {iv: ivReading, cipherKey: ckReading} =
            extractCipherKeyAndIvFromPackedPoint(
                packPublicKey(readingEcdhSharedKey),
            );

        const decryptedSecretRandom = decryptCipherText(
            ciphertext,
            ckReading,
            ivReading,
        );

        expect(decryptedSecretRandom).toEqual(
            bigIntToUint8Array(secretRandom, 32),
        );

        expect(ciphertext.length).toEqual(32);
    });
});
