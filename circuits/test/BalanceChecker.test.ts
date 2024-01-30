import * as path from 'path';
import {assert, expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';

describe('BalanceChecker circuit', async function (this: any) {
    let balanceChecker: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/balanceChecker.circom',
        );
        balanceChecker = await wasm_tester(input, opts);
    });

    let balanceCheckerSignals: any;
    beforeEach(async function () {
        balanceCheckerSignals = {
            isZkpToken: BigInt(0n),
            depositAmount: BigInt(0n),
            depositChange: BigInt(0n),
            withdrawAmount: BigInt(0n),
            withdrawChange: BigInt(0n),
            chargedAmountZkp: BigInt(0n),
            donatedAmountZkp: BigInt(0n),
            zAccountUtxoInZkpAmount: BigInt(0n),
            zAccountUtxoOutZkpAmount: BigInt(0n),
            totalUtxoInAmount: BigInt(0n),
            totalUtxoOutAmount: BigInt(0n),
            zAssetWeight: BigInt(0n),
            zAssetScale: BigInt(0n),
            zAssetScaleZkp: BigInt(0n),
        };
    });

    const checkWitness = async (expectedOut: any) => {
        const witness = await balanceChecker.calculateWitness(
            balanceCheckerSignals,
            true,
        );
        await balanceChecker.checkConstraints(witness);
        await balanceChecker.assertOut(witness, expectedOut);
    };

    const checkWitnessError = async (balanceCheckerSignals: any) => {
        try {
            await balanceChecker.calculateWitness(balanceCheckerSignals, true);
            console.log(
                `Unexpectedly Circom did not throw an error for input signal ${JSON.stringify(
                    balanceCheckerSignals,
                )}`,
            );
            throw new Error(`This code should never be reached!`);
        } catch (err) {
            expect(err).to.be.instanceOf(Error);
        }
    };

    describe('Valid input signals', async function () {
        it('balance should tally before and after the transaction for ZKP ZAsset', async () => {
            balanceCheckerSignals.isZkpToken = 1;
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.donatedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999000n);
            balanceCheckerSignals.totalUtxoInAmount = 0;
            balanceCheckerSignals.totalUtxoOutAmount = 110;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            let totalScaled = (100000110n - 99999000n);
            let totalWeighted = totalScaled;
            await checkWitness({
                depositScaledAmount: 10,
                depositWeightedScaledAmount: 10,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: totalScaled,
                totalWeighted: totalWeighted,
            });
        });

        it('balance should tally before and after the transaction for Non ZKP ZAsset', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.donatedAmountZkp = 0;
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999000n);
            balanceCheckerSignals.totalUtxoInAmount = 0;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            await checkWitness({
                depositScaledAmount: 10,
                depositWeightedScaledAmount: 10,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });
    });

    describe('Invalid input signals', async function () {
        it('should fail when deposit amount is 0 and deposit change is a non 0', async () => {
            balanceCheckerSignals.depositChange = 1;

            await checkWitnessError(balanceCheckerSignals);
        });

        it('should fail when withdraw amount is 0 and withdraw change is a non 0', async () => {
            balanceCheckerSignals.withdrawChange = 1;

            await checkWitnessError(balanceCheckerSignals);
        });

        it('should fail when deposit amount is not equal to "(deposit scaled amount * zAsset scale) + deposit change"', async () => {
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13);
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.depositChange = BigInt(1n);

            await checkWitnessError(balanceCheckerSignals);
        });

        it('should fail when withdraw amount is not equal to "(withdraw scaled amount * zAsset scale) + withdraw change"', async () => {
            balanceCheckerSignals.withdrawAmount = BigInt(10 ** 13);
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.withdrawChange = BigInt(1n);

            await checkWitnessError(balanceCheckerSignals);
        });

        it('should fail when zAssetScale <= 0', async () => {
            balanceCheckerSignals.zAssetScale = 0;

            await checkWitnessError(balanceCheckerSignals);
        });

        it('should fail when zAssetScaleZkp <= 0', async () => {
            balanceCheckerSignals.zAssetScale = 1;
            balanceCheckerSignals.zAssetScaleZkp = 0;

            await checkWitnessError(balanceCheckerSignals);
        });
    });
});
