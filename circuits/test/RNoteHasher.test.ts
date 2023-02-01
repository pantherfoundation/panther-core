import * as path from 'path';
import {expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {babyjub} from 'circomlibjs';
const F = babyjub.F;

import {getOptions} from './helpers/circomTester';
import {getRandomInt} from './helpers/utility';
import {poseidon} from 'circomlibjs';

describe('RNoteHasher circuit', async function (this: any) {
    interface Input {
        spendPk: bigint[];
        amount: bigint;
    }

    let signalInput: Input;
    let rNoteHasher: any;
    let pk: bigint[] = [BigInt(1), BigInt(2)];
    let amount: bigint;

    this.timeout(10000000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/rNoteHasher.circom',
        );
        rNoteHasher = await wasm_tester(input, opts);
    });

    beforeEach(async function () {
        pk = [BigInt(0), BigInt(0)];
        amount = BigInt(0);
        signalInput = {
            spendPk: [F.e(pk[0]), F.e(pk[1])],
            amount: F.e(amount),
        };
    });

    describe('Valid input signals', async function () {
        it('should compute valid poseidon hash when input signal values are 0', async function () {
            const w = await rNoteHasher.calculateWitness(signalInput, true);

            const out = poseidon([BigInt(0), BigInt(0), BigInt(0)]);

            await rNoteHasher.assertOut(w, {out: out});
        });

        it('should computes valid poseidon hash when input signal values are random', async function () {
            pk = [
                BigInt(getRandomInt(0, 123456789)),
                BigInt(getRandomInt(0, 123456789)),
            ];
            amount = BigInt(getRandomInt(0, 123456789));
            signalInput = {
                spendPk: [F.e(pk[0]), F.e(pk[1])],
                amount: F.e(amount),
            };

            const w = await rNoteHasher.calculateWitness(signalInput, true);

            const out = poseidon([pk[0], pk[1], amount]);

            await rNoteHasher.assertOut(w, {out: out});
        });
    });

    describe('Invalid input signals', async function () {
        it('should fail to compute valid poseidon hash when signal values are above signal range', async () => {
            let value = BigInt(0);
            for (let i = 0; i <= 256; i++) {
                value += BigInt(Math.pow(2, i));
            }

            pk = [value, value];
            amount = value;
            signalInput = {
                spendPk: [value, value],
                amount: value,
            };

            const w = await rNoteHasher.calculateWitness(signalInput, true);

            const out = poseidon([pk[0], pk[1], amount]);

            try {
                await rNoteHasher.assertOut(w, {out: out});
                console.log(`Error occured for input signal ${value}`);
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });
    });
});
