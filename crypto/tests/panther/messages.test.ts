// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {describe, expect} from '@jest/globals';

import {
    generateRandomKeypair,
    PACKED_PUB_KEY_SIZE,
} from '../../src/base/keypairs';
import {
    encodeZAccountUTXOMessage,
    decodeZAccountUTXOMessage,
    encryptAndPackZAccountUTXOMessage,
    unpackAndDecryptZAccountUTXOMessage,
} from '../../src/panther/messages';
import {Keypair} from '../../src/types/keypair';
import {bigintToBinaryString} from '../../src/utils/bigint-conversions';

interface Parameter {
    param: keyof ArgsType;
    value: bigint;
    error: string;
}

type ArgsType = {
    secretRandom: bigint;
    networkId: bigint;
    zoneId: bigint;
    nonce: bigint;
    expiryTime: bigint;
    amountZkp: bigint;
    amountPrp: bigint;
    totalAmountPerTimePeriod: bigint;
};

describe('panther messages', () => {
    let secretRandom: bigint;
    let networkId: bigint;
    let zoneId: bigint;
    let nonce: bigint;
    let expiryTime: bigint;
    let amountZkp: bigint;
    let amountPrp: bigint;
    let totalAmountPerTimePeriod: bigint;
    let encodedzAccountUTXOMessage: string;
    let keypair: Keypair;

    beforeEach(() => {
        secretRandom = 123n;
        networkId = 1n;
        zoneId = 1n;
        nonce = 1n;
        expiryTime = 1000n;
        amountZkp = 5000n;
        amountPrp = 2000n;
        totalAmountPerTimePeriod = 10000n;
        encodedzAccountUTXOMessage =
            '0x000000000000000000000000000000000000000000000000000000000000007b040004000400000fa00000000000004e20000000000007d00000000000002710';
        keypair = generateRandomKeypair();
    });

    describe('zAccount UTXO encryption', () => {
        it('encodes and decodes message', () => {
            const encoded = encodeZAccountUTXOMessage(
                secretRandom,
                networkId,
                zoneId,
                nonce,
                expiryTime,
                amountZkp,
                amountPrp,
                totalAmountPerTimePeriod,
            );

            const decoded = decodeZAccountUTXOMessage(
                bigintToBinaryString(BigInt(encoded), 512),
            );

            expect(encoded).toEqual(encodedzAccountUTXOMessage);
            expect(decoded.secretRandom).toEqual(secretRandom);
            expect(decoded.networkId).toEqual(networkId);
            expect(decoded.zoneId).toEqual(zoneId);
            expect(decoded.nonce).toEqual(nonce);
            expect(decoded.expiryTime).toEqual(expiryTime);
            expect(decoded.amountZkp).toEqual(amountZkp);
            expect(decoded.amountPrp).toEqual(amountPrp);
            expect(decoded.totalAmountPerTimePeriod).toEqual(
                totalAmountPerTimePeriod,
            );
        });

        const parameters: Parameter[] = [
            {
                param: 'secretRandom',
                value: 2n ** 256n,
                error: 'secretRandom is not in the BabyJubJub suborder',
            },
            {
                param: 'networkId',
                value: 2n ** 6n,
                error: 'networkId number exceeds 6 bits',
            },
            {
                param: 'zoneId',
                value: 2n ** 16n,
                error: 'zoneId number exceeds 16 bits',
            },
            {
                param: 'nonce',
                value: 2n ** 16n,
                error: 'nonce number exceeds 16 bits',
            },
            {
                param: 'expiryTime',
                value: 2n ** 32n,
                error: 'expiryTime number exceeds 32 bits',
            },
            {
                param: 'amountZkp',
                value: 2n ** 64n,
                error: 'amountZkp number exceeds 64 bits',
            },
            {
                param: 'amountPrp',
                value: 2n ** 58n,
                error: 'amountPrp number exceeds 58 bits',
            },
            {
                param: 'totalAmountPerTimePeriod',
                value: 2n ** 64n,
                error: 'totalAmountPerTimePeriod number exceeds 64 bits',
            },
        ];

        parameters.forEach(({param, value, error}) => {
            it(`throws error when ${param} exceeds max bits`, () => {
                const args: ArgsType = {
                    secretRandom,
                    networkId,
                    zoneId,
                    nonce,
                    expiryTime,
                    amountZkp,
                    amountPrp,
                    totalAmountPerTimePeriod,
                };

                args[param] = value;
                const tupleArgs = [...Object.values(args)] as [
                    bigint,
                    bigint,
                    bigint,
                    bigint,
                    bigint,
                    bigint,
                    bigint,
                    bigint,
                ];

                expect(() => encodeZAccountUTXOMessage(...tupleArgs)).toThrow(
                    error,
                );
            });
        });

        it('encrypts and decrypts correctly', () => {
            const message = encryptAndPackZAccountUTXOMessage(
                secretRandom,
                networkId,
                zoneId,
                nonce,
                expiryTime,
                amountZkp,
                amountPrp,
                totalAmountPerTimePeriod,
                keypair.publicKey,
            );

            const result = unpackAndDecryptZAccountUTXOMessage(
                message,
                keypair.privateKey,
            );

            expect(result.secretRandom).toEqual(secretRandom);
            expect(result.networkId).toEqual(networkId);
            expect(result.zoneId).toEqual(zoneId);
            expect(result.nonce).toEqual(nonce);
            expect(result.expiryTime).toEqual(expiryTime);
            expect(result.amountZkp).toEqual(amountZkp);
            expect(result.amountPrp).toEqual(amountPrp);
            expect(result.totalAmountPerTimePeriod).toEqual(
                totalAmountPerTimePeriod,
            );
        });
    });
});
