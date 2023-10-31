import * as path from 'path';
import crypto from 'crypto';
import {expect} from 'chai';
import {bufferToBigInt} from '@panther-core/crypto/lib/utils/bigint-conversions';
import {generateRandomInBabyJubSubField} from '@panther-core/crypto/lib/base/field-operations';
import {
    derivePubKeyFromPrivKey,
    deriveChildPubKeyFromRootPubKey,
} from '@panther-core/crypto/lib/base/keypairs';
import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';

describe('PubKeyDeriver circuit', async function (this: any) {
    let pubKeyDeriver: any;
    let randomRootPubKey: bigint[];
    let randomRootPrivKey: bigint;
    let random: bigint;
    let expectedPubKey: bigint[];

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/pubKeyDeriver.circom',
        );
        pubKeyDeriver = await wasm_tester(input, opts);
    });

    beforeEach(async function () {
        randomRootPrivKey = generateRandomInBabyJubSubField();
        randomRootPubKey = derivePubKeyFromPrivKey(randomRootPrivKey);
        random = generateRandomInBabyJubSubField();
        expectedPubKey = deriveChildPubKeyFromRootPubKey(
            randomRootPubKey,
            random,
        );
    });

    describe('Valid input signals', async function () {
        it('derives child public key correctly', async () => {
            const witness = await pubKeyDeriver.calculateWitness(
                {
                    rootPubKey: randomRootPubKey,
                    random,
                },
                true,
            );
            await pubKeyDeriver.assertOut(witness, {
                derivedPubKey: expectedPubKey,
            });
        });
    });

    describe('Invalid input signals', async function () {
        it('throws error if random signal is above 253 bits', async () => {
            const randomAbove253bits = 2n ** 254n + random;
            try {
                await pubKeyDeriver.calculateWitness(
                    {
                        rootPubKey: randomRootPubKey,
                        randomAbove253bits,
                    },
                    true,
                );
                console.log(
                    `Unexpectedly Circom did not throw an error for input signal ${{
                        rootPubKey: randomRootPubKey,
                        randomAbove253bits,
                    }}`,
                );
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });

        it('throws error if pubKey X signal is above 253 bits', async () => {
            randomRootPubKey[0] = randomRootPubKey[0] + 2n ** 254n;
            try {
                await pubKeyDeriver.calculateWitness(
                    {
                        rootPubKey: randomRootPubKey,
                        random,
                    },
                    true,
                );
                console.log(
                    `Unexpectedly Circom did not throw an error for input signal ${JSON.stringify(
                        {
                            randomRootPubKey,
                            random,
                        },
                    )}`,
                );
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });

        it('throws error if pubKey Y signal is above 253 bits', async () => {
            randomRootPubKey[1] = randomRootPubKey[1] + 2n ** 254n;
            try {
                await pubKeyDeriver.calculateWitness(
                    {
                        rootPubKey: randomRootPubKey,
                        random,
                    },
                    true,
                );
                console.log(
                    `Unexpectedly Circom did not throw an error for input signal ${JSON.stringify(
                        {
                            randomRootPubKey,
                            random,
                        },
                    )}`,
                );
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });
    });
});
