import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {babyjub} from 'circomlibjs';
const F = babyjub.F;

import {getOptions} from './helpers/circomTester';

import {poseidon} from 'circomlibjs';

const getRandomInt = (min: number, max: number) => {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min) + min);
};

describe('NoteHasherPacked circuit', async function (this: any) {
    let circuit: any;

    this.timeout(10000000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/noteHasherPacked.circom',
        );
        circuit = await wasm_tester(input, opts);
    });

    it('Should compute valid commitment for ZERO', async function () {
        let value = BigInt(0);
        const input = {
            spendPk: [F.e(value), F.e(value)],
            amount: F.e(value),
            token: F.e(value),
            createTime: F.e(value),
        };

        // poseidon(pk[0],pk[1],packed(amount,token,createTime))
        const out = poseidon([value, value, value]);

        const w = await circuit.calculateWitness(input, true);

        await circuit.assertOut(w, {out: out});
    });

    it('Should compute valid commitment for random input', async function () {
        const pk = [
            BigInt(getRandomInt(0, 123456789)),
            BigInt(getRandomInt(0, 123456789)),
        ];
        const amount = BigInt(getRandomInt(0, 123456789));
        const token = BigInt(getRandomInt(0, 123456789));
        const createTime = BigInt(Math.round(Date.now() / 1000));
        const input = {
            spendPk: [F.e(pk[0]), F.e(pk[1])],
            amount: F.e(amount),
            token: F.e(token),
            createTime: F.e(createTime),
        };
        const packed =
            (amount << BigInt(192)) | (token << BigInt(32)) | createTime;
        // poseidon(pk[0],pk[1],packed(amount,token,createTime))
        const out = poseidon([pk[0], pk[1], packed]);

        const w = await circuit.calculateWitness(input, true);

        await circuit.assertOut(w, {out: out});
    });
});
