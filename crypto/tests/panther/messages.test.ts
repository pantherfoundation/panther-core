// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {describe, expect} from '@jest/globals';

import {generateRandomInBabyJubSubField} from '../../src/base/field-operations';
import {generateRandomKeypair} from '../../src/base/keypairs';
import {
    encryptAndPackZAccountUTXOMessage,
    unpackAndDecryptZAccountUTXOMessage,
    encryptAndPackZAssetPrivUTXOMessage,
    unpackAndDecryptZAssetPrivUTXOMessage,
    unpackAndDecryptSpentUTXOMessage,
    encryptAndPackZAssetUTXOMessage,
    unpackAndDecryptZAssetUTXOMessage,
    encryptAndPackSpentUTXOMessage,
} from '../../src/panther/messages';
import {
    Message,
    SpentUTXOMessage,
    ZAccountUTXOMessage,
    ZAssetPrivUTXOMessage,
    ZAssetUTXOMessage,
} from '../../src/types/message';

const commonValues: Message = {
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
    spentUtxoCommitment1: 123n,
    spentUtxoCommitment2: 321n,
    scaledAmount: 123n,
};

const keypair = generateRandomKeypair();
const zAccountSecretRandom = generateRandomInBabyJubSubField();

describe('Panther messages encryption', () => {
    const runCommonTests = (result: any) => {
        for (const key in commonValues) {
            if (Object.prototype.hasOwnProperty.call(result, key)) {
                expect(result[key]).toEqual(
                    commonValues[key as keyof typeof commonValues],
                );
            }
        }
    };

    const runTest = (
        encryptFunc: any,
        decryptFunc: any,
        values:
            | ZAccountUTXOMessage
            | ZAssetPrivUTXOMessage
            | ZAssetUTXOMessage
            | SpentUTXOMessage,
        extraArgsEncrypt: any[] = [],
        extraArgsDecrypt: any[] = [],
    ) => {
        it('encrypts and decrypts correctly', () => {
            const message = encryptFunc(
                values,
                keypair.publicKey,
                ...extraArgsEncrypt,
            );
            const result = decryptFunc(
                message,
                keypair.privateKey,
                ...extraArgsDecrypt,
            );
            runCommonTests(result);
        });
    };

    describe('zAccount UTXO', () => {
        runTest(
            encryptAndPackZAccountUTXOMessage,
            unpackAndDecryptZAccountUTXOMessage,
            commonValues as ZAccountUTXOMessage,
        );
    });

    describe('zAssets Private UTXO', () => {
        runTest(
            encryptAndPackZAssetPrivUTXOMessage,
            unpackAndDecryptZAssetPrivUTXOMessage,
            commonValues as ZAssetPrivUTXOMessage,
        );
    });

    describe('zAssets UTXO', () => {
        runTest(
            encryptAndPackZAssetUTXOMessage,
            unpackAndDecryptZAssetUTXOMessage,
            commonValues as ZAssetUTXOMessage,
        );
    });

    describe('SpentUTXO Message', () => {
        runTest(
            encryptAndPackSpentUTXOMessage,
            unpackAndDecryptSpentUTXOMessage,
            commonValues as SpentUTXOMessage,
            [zAccountSecretRandom],
            [zAccountSecretRandom],
        );
    });
});
