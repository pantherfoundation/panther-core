// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {describe, expect} from '@jest/globals';

import {generateRandomKeypair} from '../../src/base/keypairs';
import {
    encryptAndPackZAccountUTXOMessage,
    unpackAndDecryptZAccountUTXOMessage,
    encryptAndPackZAssetUTXOMessage,
    unpackAndDecryptZAssetUTXOMessage,
} from '../../src/panther/messages';
import {Keypair} from '../../src/types/keypair';
import {ZAccountUTXOMessage, ZAssetUTXOMessage} from '../../src/types/message';

describe('Panther messages encryption', () => {
    let keypair: Keypair;
    let commonValues: ZAccountUTXOMessage | ZAssetUTXOMessage;

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
        };
        keypair = generateRandomKeypair();
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
});
