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
            './test/circuits/balanceCheckerMain.circom',
        );
        balanceChecker = await wasm_tester(input, opts);
    });

    let balanceCheckerSignals: any;
    beforeEach(async function () {
        balanceCheckerSignals = {
            isZkpToken: BigInt(0),
            depositAmount: BigInt(0),
            withdrawAmount: BigInt(0),
            chargedAmountZkp: BigInt(0),
            addedAmountZkp: BigInt(0),
            zAccountUtxoInZkpAmount: BigInt(0),
            zAccountUtxoOutZkpAmount: BigInt(0),
            totalUtxoInAmount: BigInt(0),
            totalUtxoOutAmount: BigInt(0),
            zAssetWeight: BigInt(0),
            zAssetScale: BigInt(0),
            zAssetScaleZkp: BigInt(0),
            kytDepositChargedAmountZkp: BigInt(0),
            kycWithdrawOrKytChargedAmountZkp: BigInt(0),
            kytInternalChargedAmountZkp: BigInt(0),
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
        it('balance should tally for native token deposit transaction without kytDepositChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 1; // zZKP tokenId
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13); // deposit tx
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999100n);
            balanceCheckerSignals.totalUtxoInAmount = 0;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 10,
                depositWeightedScaledAmount: 10,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 1010,
                totalWeighted: 1010,
            });
        });

        it('balance should tally for native token deposit transaction with kytDepositChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 1; // zZKP tokenId
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13); // deposit tx
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999090n);
            balanceCheckerSignals.totalUtxoInAmount = 0;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;
            balanceCheckerSignals.kytDepositChargedAmountZkp = BigInt(10 ** 13);

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 10,
                depositWeightedScaledAmount: 10,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 1020,
                totalWeighted: 1020,
            });
        });

        it('balance should tally for ERC20 token deposit transaction without kytDepositChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999100n);
            balanceCheckerSignals.totalUtxoInAmount = 0;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 10,
                depositWeightedScaledAmount: 10,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });

        it('balance should tally for ERC20 token deposit transaction with kytDepositChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.depositAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999090n);
            balanceCheckerSignals.totalUtxoInAmount = 0;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;
            balanceCheckerSignals.kytDepositChargedAmountZkp = BigInt(10 ** 13);

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 10,
                depositWeightedScaledAmount: 10,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });

        it('balance should tally for native token withdraw transaction without kycWithdrawOrKytChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 1; // Native token
            balanceCheckerSignals.withdrawAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999100n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 0;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 10,
                withdrawScaledAmount: 10,
                totalScaled: 1010,
                totalWeighted: 1010,
            });
        });

        it('balance should tally for native token withdraw transaction with kycWithdrawOrKytChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 1; // zZKP tokenId
            balanceCheckerSignals.withdrawAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999090n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 0;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;
            balanceCheckerSignals.kycWithdrawOrKytChargedAmountZkp = BigInt(
                10 ** 13,
            );

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 10,
                withdrawScaledAmount: 10,
                totalScaled: 1020,
                totalWeighted: 1020,
            });
        });

        it('balance should tally for ERC20 token withdraw transaction without kycWithdrawOrKytChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.withdrawAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999100n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 0;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 10,
                withdrawScaledAmount: 10,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });

        it('balance should tally for ERC20 token withdraw transaction with kycWithdrawOrKytChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.withdrawAmount = BigInt(10 ** 13);
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999090n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 0;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;
            balanceCheckerSignals.kycWithdrawOrKytChargedAmountZkp = BigInt(
                10 ** 13,
            );

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 10,
                withdrawScaledAmount: 10,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });

        it('balance should tally for native token internal transaction without kytInternalChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 1; // Native token
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999100n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            // Inferred - no external deposit amount, no external withdraw amount
            // balanceCheckerSignals.depositAmount = 0;
            // balanceCheckerSignals.withdrawAmount = 0;
            // balanceCheckerSignals.kytInternalChargedAmountZkp = 0;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 1010,
                totalWeighted: 1010,
            });
        });

        it('balance should tally for native token internal transaction with kytInternalChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 1; // Native token
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999090n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;
            balanceCheckerSignals.kytInternalChargedAmountZkp = BigInt(
                10 ** 13,
            );

            // Inferred - no external deposit amount, no external withdraw amount
            // balanceCheckerSignals.depositAmount = 0;
            // balanceCheckerSignals.withdrawAmount = 0;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 1020,
                totalWeighted: 1020,
            });
        });

        it('balance should tally for ERC20 token internal transaction without kytInternalChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999100n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;

            // Inferred - no external deposit amount, no external withdraw amount
            // balanceCheckerSignals.depositAmount = 0;
            // balanceCheckerSignals.withdrawAmount = 0;
            // balanceCheckerSignals.kytInternalChargedAmountZkp = 0;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });

        it('balance should tally for ERC20 token internal transaction with kytInternalChargedAmountZkp', async () => {
            balanceCheckerSignals.isZkpToken = 0;
            balanceCheckerSignals.chargedAmountZkp = BigInt(10 ** 15);
            balanceCheckerSignals.addedAmountZkp = BigInt(10 ** 14);
            balanceCheckerSignals.zAccountUtxoInZkpAmount = BigInt(100000000n);
            balanceCheckerSignals.zAccountUtxoOutZkpAmount = BigInt(99999090n);
            balanceCheckerSignals.totalUtxoInAmount = 10;
            balanceCheckerSignals.totalUtxoOutAmount = 10;
            balanceCheckerSignals.zAssetScale = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetScaleZkp = BigInt(10 ** 12);
            balanceCheckerSignals.zAssetWeight = 1;
            balanceCheckerSignals.kytInternalChargedAmountZkp = BigInt(
                10 ** 13,
            );

            // Inferred - no external deposit amount, no external withdraw amount
            // balanceCheckerSignals.depositAmount = 0;
            // balanceCheckerSignals.withdrawAmount = 0;

            const wtns = await balanceChecker.calculateWitness(
                balanceCheckerSignals,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[22],
                wtns[23],
                wtns[24],
                wtns[25],
                wtns[26],
                wtns[27],
            ];

            await balanceChecker.assertOut(wtnsFormattedOutput, {
                depositScaledAmount: 0,
                depositWeightedScaledAmount: 0,
                withdrawWeightedScaledAmount: 0,
                withdrawScaledAmount: 0,
                totalScaled: 10,
                totalWeighted: 10,
            });
        });
    });

    describe('Invalid input signals', async function () {
        it('should fail when zAssetScale <= 0', async () => {
            balanceCheckerSignals.zAssetScale = 0;

            await checkWitnessError(balanceCheckerSignals);
        });

        it('should fail when zAssetScaleZkp <= 0', async () => {
            balanceCheckerSignals.zAssetScale = 1;
            balanceCheckerSignals.zAssetScaleZkp = 0;

            await checkWitnessError(balanceCheckerSignals);
        });

        /* Audit Bug - 4.1.1 V-PANC-VUL-001: depositScaledAmount is under-constrained
        When depositScaledAmountTmp which is an intermediate signal is under constrained a malicious actor can manipulate the operations in the equation to overflow while satisfying the equality constraints.
       
        Ex: depositScaledAmountTmp = 21802741923121153053409505722814863857733722351976909209543133076471996743681
            zAccountUtxoInZkpAmount = 1
            zAssetScale = 256
            zAccountUtxoOutZkpAmount: 85500948718122168836900022442411230814642048439125134155071110103811751937
            depositAmount = 1

        In this case a malicious actor can pass a very low zAccountUtxoInZkpAmount and forge a very high zAccountUtxoOutZkpAmount amount which ends up as $ZKP balance in their zAccount.
        
        This bug is fixed in the BalanceChecker template by constraining the intermediate signal value to be less than 2**252.
        */
        it('should fail when depositScaledAmountTmp has an overflowing value', async () => {
            balanceCheckerSignals.zAssetScale = 256;
            balanceCheckerSignals.zAccountUtxoInZkpAmount = 1;
            balanceCheckerSignals.zAccountUtxoOutZkpAmount =
                85500948718122168836900022442411230814642048439125134155071110103811751937n;
            balanceCheckerSignals.zAssetScaleZkp = 1;
            balanceCheckerSignals.depositAmount = 1;

            await checkWitnessError(balanceCheckerSignals);
        });

        /* Audit Bug - 4.1.4 V-PANC-VUL-004: donatedScaledAmountZkp is under-constrained
        When addedScaledAmountZkp which is an intermediate signal is under constrained a malicious actor can manipulate the operations in the equation to overflow while satisfying the equality constraints.
       
        Ex: addedScaledAmountZkp = 21802741923121153053409505722814863857733722351976909209543133076471996743681
            zAccountUtxoInZkpAmount = 1
            zAssetScaleZkp = 256
            zAccountUtxoOutZkpAmount: 85500948718122168836900022442411230814642048439125134155071110103811751937
            depositAmount = 1

        In this case a malicious actor can pass a very low zAccountUtxoInZkpAmount and forge a very high zAccountUtxoOutZkpAmount amount which ends up as $ZKP balance in their zAccount.
        
        This bug is fixed in the BalanceChecker template by constraining the intermediate signal value to be less than 2**252.
        */
        it('should fail when addedScaledAmountZkp has an overflowing value', async () => {
            balanceCheckerSignals.zAssetScale = 1;
            balanceCheckerSignals.zAccountUtxoInZkpAmount = 1;
            balanceCheckerSignals.zAccountUtxoOutZkpAmount =
                85500948718122168836900022442411230814642048439125134155071110103811751937n;
            balanceCheckerSignals.zAssetScaleZkp = 256;
            balanceCheckerSignals.addedAmountZkp = 1;

            await checkWitnessError(balanceCheckerSignals);
        });

        /* Audit Bug - 4.1.3 V-PANC-VUL-003: withdrawScaledAmount is under-constrained
        When withdrawScaledAmountTmp which is an intermediate signal is under constrained a malicious actor can manipulate the operations in the equation to overflow while satisfying the equality constraints.
       
        Ex: withdrawScaledAmountTmp = 21802741923121153053409505722814863857733722351976909209543133076471996743681
            zAccountUtxoInZkpAmount = 1
            zAssetScale = 256
            zAccountUtxoOutZkpAmount: 85500948718122168836900022442411230814642048439125134155071110103811751937
            withdrawAmount = 1

        In this case a malicious actor can pass a very low zAccountUtxoInZkpAmount and forge a very high zAccountUtxoOutZkpAmount amount which ends up as $ZKP balance in their zAccount.
        
        This bug is fixed in the BalanceChecker template by constraining the intermediate signal value to be less than 2**252.
        */
        it('should fail when withdrawScaledAmountTmp has an overflowing value', async () => {
            balanceCheckerSignals.zAssetScale = 256;
            balanceCheckerSignals.zAccountUtxoInZkpAmount = 1;
            balanceCheckerSignals.zAccountUtxoOutZkpAmount =
                85500948718122168836900022442411230814642048439125134155071110103811751937n;
            balanceCheckerSignals.zAssetScaleZkp = 1;
            balanceCheckerSignals.withdrawAmount = 1;

            await checkWitnessError(balanceCheckerSignals);
        });

        /* Audit Bug - 4.1.6 V-PANC-VUL-006: chargedScaledAmountZkp is under-constrained
        When chargedScaledAmountZkp which is an intermediate signal is under constrained a malicious actor can manipulate the operations in the equation to overflow while satisfying the equality constraints.
       
        Ex: chargedScaledAmountZkp = 21802741923121153053409505722814863857733722351976909209543133076471996743681
            zAccountUtxoInZkpAmount = 1
            zAssetScale = 256
            zAccountUtxoOutZkpAmount: 85500948718122168836900022442411230814642048439125134155071110103811751937
            chargedAmountZkp = 1

        In this case a malicious actor can pass a very low zAccountUtxoInZkpAmount and forge a very high zAccountUtxoOutZkpAmount amount which ends up as $ZKP balance in their zAccount.
        
        This bug is fixed in the BalanceChecker template by constraining the intermediate signal value to be less than 2**252.
        */
        it('should fail when chargedScaledAmountZkp has an overflowing value', async () => {
            balanceCheckerSignals.zAssetScale = 1;
            balanceCheckerSignals.zAccountUtxoInZkpAmount = 1;
            balanceCheckerSignals.zAccountUtxoOutZkpAmount =
                85500948718122168836900022442411230814642048439125134155071110103811751937n;
            balanceCheckerSignals.zAssetScaleZkp = 256;
            balanceCheckerSignals.chargedAmountZkp = 1;

            await checkWitnessError(balanceCheckerSignals);
        });
    });
});
