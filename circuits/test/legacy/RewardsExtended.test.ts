import * as path from 'path';
import {expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './../helpers/circomTester';

describe('RewardsExtended circuit', async function (this: any) {
    let rewardsExtended: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/rewardsExtended.circom',
        );
        rewardsExtended = await wasm_tester(input, opts);
    });

    let rewardsExtendedSignals: any;
    beforeEach(async function () {
        rewardsExtendedSignals = {
            depositAmount: 0,
            forTxReward: 0,
            forUtxoReward: 0,
            forDepositReward: 0,
            spendTime: 0,
            assetWeight: 0,
            utxoInAmount: [0, 0],
            utxoInCreateTime: [0, 0],
        };
    });

    const checkWitness = async (expectedOut: any) => {
        const witness = await rewardsExtended.calculateWitness(
            rewardsExtendedSignals,
            true,
        );
        await rewardsExtended.checkConstraints(witness);
        await rewardsExtended.assertOut(witness, expectedOut);
    };

    const checkWitnessError = async (rewardsExtendedSignals: any) => {
        try {
            await rewardsExtended.calculateWitness(
                rewardsExtendedSignals,
                true,
            );
            console.log(
                `Unexpectedly Circom did not throw an error for input signal ${JSON.stringify(
                    rewardsExtendedSignals,
                )}`,
            );
            throw new Error(`This code should never be reached!`);
        } catch (err) {
            expect(err).to.be.instanceOf(Error);
        }
    };

    describe('Valid input signals', async function () {
        it('should compute reward PRP amount for the tx when signals are 0', async () => {
            await checkWitness({amountPrp: 0});
        });

        // Deposit tx - positive scenario
        // When the spendTime, utxoInAmount and utxoInCreateTime are 0
        it('should compute reward PRP amount when spendTime, utxoInAmount and utxoInCreateTime are 0 for Deposit tx', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 0;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [0, 0];
            rewardsExtendedSignals.utxoInCreateTime = [0, 0];

            await checkWitness({amountPrp: 35009});
        });

        // Deposit tx - negative scenario
        // When the spendTime is non zero, utxoInAmount and utxoInCreateTime are 0
        // spendTime must be ignored
        it('should compute reward PRP amount when spendTime is non zero and utxoInAmount and utxoInCreateTime are 0 for Deposit tx', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 1704784471;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [0, 0];
            rewardsExtendedSignals.utxoInCreateTime = [0, 0];

            await checkWitness({amountPrp: 35009});
        });

        // Internal transaction - positive scenario where spendTime > utxoInCreateTime
        it('should compute reward PRP amount when spendTime > utxoInCreateTime (Valid UTXO) for internal tx', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 1704784474;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [1, 1];
            rewardsExtendedSignals.utxoInCreateTime = [1704784471, 1704784471];

            await checkWitness({amountPrp: 35009});
        });

        // Internal transaction - negative scenario where spendTime < utxoInCreateTime
        it('should compute reward PRP amount when spendTime < utxoInCreateTime (Invalid UTXO) for internal tx', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 1704784471;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [1, 1];
            rewardsExtendedSignals.utxoInCreateTime = [1704784474, 1704784474];

            await checkWitness({amountPrp: 35009});
        });

        // 2 tests below are to prove that deposit amount and the time spent by the UTXO in the pool is directly proportional to the rewards.
        it('should compute reward PRP amount for the tx with increased time spent by UTXO in the pool', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 1704784471;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [100, 100];
            rewardsExtendedSignals.utxoInCreateTime = [1673337151, 1673337151]; // UTXO's got created an year before

            await checkWitness({amountPrp: 35010});
        });

        it('should compute reward PRP amount for the tx with increased deposit amount in the pool', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000000; // 10 ** 15 - Increased deposit amount
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 1704784471;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [100, 100];
            rewardsExtendedSignals.utxoInCreateTime = [1673337151, 1673337151];

            await checkWitness({amountPrp: 35000009});
        });
    });

    describe('Invalid input signals', async function () {
        it('should throw error when spendTime is higher than 32 bits', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 2 ** 32 + 1; // spendTime is above 32 bits range
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [0, 0];
            rewardsExtendedSignals.utxoInCreateTime = [0, 0];

            await checkWitnessError(rewardsExtendedSignals);
        });

        it('should throw error when utxoInCreateTimes are higher than 32 bits', async () => {
            rewardsExtendedSignals.depositAmount = 1000000000000;
            rewardsExtendedSignals.forTxReward = 10;
            rewardsExtendedSignals.forUtxoReward = 1828;
            rewardsExtendedSignals.forDepositReward = 57646075;
            rewardsExtendedSignals.spendTime = 1704784471;
            rewardsExtendedSignals.assetWeight = 700;
            rewardsExtendedSignals.utxoInAmount = [0, 0];
            rewardsExtendedSignals.utxoInCreateTime = [
                2 ** 32 + 1,
                2 ** 32 + 1,
            ]; // utxoInCreateTime is above 32 bits range

            await checkWitnessError(rewardsExtendedSignals);
        });
    });
});
