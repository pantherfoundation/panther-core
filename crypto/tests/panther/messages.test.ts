// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {describe, expect} from '@jest/globals';

import {generateRandomInBabyJubSubField} from '../../src/base/field-operations';
import {generateRandomKeypair} from '../../src/base/keypairs';
import {
    encryptAndPackZAccountUTXOMessage,
    unpackAndDecryptZAccountUTXOMessage,
    encryptAndPackZAssetUTXOMessage,
    unpackAndDecryptZAssetUTXOMessage,
    encryptAndPackCommitmentMessage,
    unpackAndDecryptCommitmentMessage,
} from '../../src/panther/messages';
import {Keypair, PrivateKey} from '../../src/types/keypair';
import {
    CommitmentMessage,
    ZAccountUTXOMessage,
    ZAssetUTXOMessage,
} from '../../src/types/message';

describe('Panther messages encryption', () => {
    let keypair: Keypair;
    let zAccountSecretRandom: PrivateKey;
    let commonValues:
        | ZAccountUTXOMessage
        | ZAssetUTXOMessage
        | CommitmentMessage;

    beforeEach(() => {
        commonValues = {
            secretRandom: 123n,
            networkId: 1n,
            zoneId: 1n,
            nonce: 1n,
            expiryTime: 1000n,
            amountZkp: 5000n,
            amountPrp: 2000n,
            totalAmountPerTimePeriod: 10_000n,
            zAccountId: 1n,
            zAssetId: 1n,
            originNetworkId: 1n,
            targetNetworkId: 1n,
            originZoneId: 1n,
            targetZoneId: 1n,
            commitment: 123n,
        };
        keypair = generateRandomKeypair();
        zAccountSecretRandom = generateRandomInBabyJubSubField();
    });

    // Function to handle common encryption and decryption tests
    const runCommonTests = (result: any) => {
        for (const key in commonValues) {
            if (Object.prototype.hasOwnProperty.call(result, key)) {
                expect(result[key]).toEqual(
                    commonValues[key as keyof typeof commonValues],
                );
            }
        }
    };

    describe('zAccount UTXO', () => {
        it('encrypts and decrypts correctly', () => {
            const message = encryptAndPackZAccountUTXOMessage(
                commonValues as ZAccountUTXOMessage,
                keypair.publicKey,
            );

            const result = unpackAndDecryptZAccountUTXOMessage(
                message,
                keypair.privateKey,
            );

            runCommonTests(result);
        });
    });

    describe('zAssets UTXO', () => {
        it('encrypts and decrypts correctly', () => {
            const message = encryptAndPackZAssetUTXOMessage(
                commonValues as ZAssetUTXOMessage,
                keypair.publicKey,
            );

            const result = unpackAndDecryptZAssetUTXOMessage(
                message,
                keypair.privateKey,
            );

            runCommonTests(result);
        });
    });

    describe('Commitment Message', () => {
        it('encrypts and decrypts correctly', () => {
            const message = encryptAndPackCommitmentMessage(
                commonValues as CommitmentMessage,
                zAccountSecretRandom,
                keypair.publicKey,
            );

            const result = unpackAndDecryptCommitmentMessage(
                message,
                zAccountSecretRandom,
                keypair.privateKey,
            );

            runCommonTests(result);
        });
    });
});
