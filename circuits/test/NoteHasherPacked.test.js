const path = require('path');
const wasm_tester = require('circom_tester').wasm;
const F = require('circomlibjs').babyjub.F;
const {getOptions} = require('./helpers/circomTester');
const poseidon = require('circomlibjs').poseidon;

const getRandomInt = (min, max) => {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min) + min);
};

describe('NoteHasherPacked circuit', async () => {
    let circuit;

    before(async () => {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/noteHasherPacked.circom',
        );
        circuit = await wasm_tester(input, opts);
    });

    it('Should compute valid commitment for ZERO', async () => {
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

    it('Should compute valid commitment for random input', async () => {
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
