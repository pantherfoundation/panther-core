import * as path from 'path';
import {expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {babyjub} from 'circomlibjs';
const F = babyjub.F;

import {getOptions} from './helpers/circomTester';
import {getRandomInt} from './helpers/utility';
import {poseidon} from 'circomlibjs';

describe('RNoteHasherPacked circuit', async function (this: any) {
    interface Input {
        spendPk: bigint[];
        amount: bigint;
        nonce: bigint;
    }

    let signalInput: Input;
    let rNoteHasherPacked: any;
    let pk: bigint[] = [BigInt(1), BigInt(2)];
    let amount: bigint;
    let nonce: bigint;

    this.timeout(10000000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/rNoteHasherPacked.circom',
        );
        rNoteHasherPacked = await wasm_tester(input, opts);
    });

    beforeEach(async function () {
        pk = [BigInt(0), BigInt(0)];
        amount = BigInt(0);
        nonce = BigInt(0);
        signalInput = {
            spendPk: [F.e(pk[0]), F.e(pk[1])],
            amount: F.e(amount),
            nonce: F.e(nonce),
        };
    });

    describe('Valid input signals', async function () {
        it('should compute valid poseidon hash when input signal values are 0', async function () {
            const w = await rNoteHasherPacked.calculateWitness(
                signalInput,
                true,
            );

            const packed = (amount << BigInt(64)) | nonce;
            const out = poseidon([pk[0], pk[1], packed]);

            await rNoteHasherPacked.assertOut(w, {out: out});
        });

        it('should computes valid poseidon hash when input signal values are random', async function () {
            pk = [
                BigInt(getRandomInt(0, 123456789)),
                BigInt(getRandomInt(0, 123456789)),
            ];
            amount = BigInt(getRandomInt(0, 123456789));
            nonce = BigInt(getRandomInt(0, 123456789));
            signalInput = {
                spendPk: [F.e(pk[0]), F.e(pk[1])],
                amount: F.e(amount),
                nonce: F.e(nonce),
            };

            const w = await rNoteHasherPacked.calculateWitness(
                signalInput,
                true,
            );

            const packed = (amount << BigInt(64)) | nonce;
            // poseidon(pk[0],pk[1],packed(amount,token,createTime))
            const out = poseidon([pk[0], pk[1], packed]);

            await rNoteHasherPacked.assertOut(w, {out: out});
        });
    });

    describe('Invalid input signals', async function () {
        it('should fail to compute valid poseidon hash when signal values are not packed properly', async function () {
            pk = [
                BigInt(getRandomInt(0, 123456789)),
                BigInt(getRandomInt(0, 123456789)),
            ];
            amount = BigInt(getRandomInt(0, 123456789));
            nonce = BigInt(getRandomInt(0, 123456789));
            signalInput = {
                spendPk: [F.e(pk[0]), F.e(pk[1])],
                amount: F.e(amount),
                nonce: F.e(nonce),
            };

            const w = await rNoteHasherPacked.calculateWitness(
                signalInput,
                true,
            );

            const packed = amount | nonce;
            const out = poseidon([pk[0], pk[1], packed]);

            try {
                await rNoteHasherPacked.assertOut(w, {out: out});
                console.log(`Error occured for input signal ${signalInput}`);
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });

        it('should fail to compute valid poseidon hash when signal values are above signal range', async function () {
            let spendPkValue = BigInt(0);
            for (let i = 0; i <= 256; i++) {
                spendPkValue += BigInt(Math.pow(2, i));
            }
            pk = [spendPkValue, spendPkValue];

            amount = BigInt(0);
            for (let i = 0; i <= 63; i++) {
                amount += BigInt(Math.pow(2, i));
            }

            nonce = BigInt(0);
            for (let i = 0; i <= 63; i++) {
                nonce += BigInt(Math.pow(2, i));
            }

            signalInput = {
                spendPk: [pk[0], pk[1]],
                amount: amount,
                nonce: nonce,
            };

            const w = await rNoteHasherPacked.calculateWitness(
                signalInput,
                true,
            );

            const packed = (amount << BigInt(64)) | nonce;
            const out = poseidon([pk[0], pk[1], packed]);

            try {
                await rNoteHasherPacked.assertOut(w, {out: out});
                console.log(`Error occured for input signal ${spendPkValue}`);
                throw new Error(`This code should never be reached!`);
            } catch (err) {
                expect(err).to.be.instanceOf(Error);
            }
        });
    });
});
