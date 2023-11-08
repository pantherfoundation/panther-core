import * as path from 'path';
import {expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {babyjub} from 'circomlibjs';
const F = babyjub.F;

import {getOptions} from './helpers/circomTester';
import {getRandomInt} from './helpers/utility';
import poseidon from 'circomlibjs/src/poseidon';

describe('NullifierHasher circuit', async function (this: any) {
    interface Input {
        privKey: bigint;
        leaf: bigint;
    }

    let signalInput: Input;
    let nullifierHasher: any;

    this.timeout(10000000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/nullifierHasher.circom',
        );
        nullifierHasher = await wasm_tester(input, opts);
    });

    beforeEach(async function () {
        signalInput = {
            privKey: BigInt(0),
            leaf: BigInt(0),
        };
    });

    describe('Valid input signals', async function () {
        it('should compute valid nullifier when input signal values are 0', async () => {
            const w = await nullifierHasher.calculateWitness(signalInput, true);

            const out = poseidon([BigInt(0), BigInt(0)]);

            await nullifierHasher.assertOut(w, {out: out});
        });

        it('should compute valid nullifier when input signal values are random', async () => {
            let value = BigInt(getRandomInt(0, 123456789));

            signalInput = {
                privKey: F.e(value),
                leaf: F.e(value),
            };

            const w = await nullifierHasher.calculateWitness(signalInput, true);

            const out = poseidon([value, value]);

            await nullifierHasher.assertOut(w, {out: out});
        });
    });

    describe('Invalid input signals', async function () {
        it('should fail to compute valid nullifier when input signal values are above signal range', async () => {
            let value = BigInt(0);
            for (let i = 0; i <= 256; i++) {
                value += BigInt(Math.pow(2, i));
            }
            signalInput = {
                privKey: value,
                leaf: value,
            };

            const w = await nullifierHasher.calculateWitness(signalInput, true);

            const out = poseidon([value, value]);

            try {
                await nullifierHasher.assertOut(w, {out: out});
                console.log(`Error occured for input signal ${value}`);
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });
    });
});
