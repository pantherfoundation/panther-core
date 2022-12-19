import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {babyjub} from 'circomlibjs';
const F = babyjub.F;

import {getOptions} from './helpers/circomTester';

describe('Rewards circuit', async function (this: any) {
    let circuitRewards: any;

    before(async () => {
        const opts = getOptions();
        const input = path.join(opts.basedir, './test/circuits/rewards.circom');
        circuitRewards = await wasm_tester(input, opts);
    });

    it('Should compute valid rewards', async function () {
        /*
    // Total reward (i.e. user reward plus relayer reward)
    R= forTxReward + (
      forUtxoReward * sum[over i](UTXO_period_i * UTXO_amount_i) +
      forDepositReward * deposit_amount
    ) * asset_weight

    S1 = forTxReward
    S2 = forDepositReward * deposit_amount
    S3 = sum[over i](UTXO_period_i * UTXO_amount_i)
    S4 = forUtxoReward * S3
    S5 = (S4 + S2)*assetWeight
    R = S1 + S5

    // User reward
    rAmount = R -  rAmountTips
    // Relayer reward
    rAmountTips
    */

        const input = {
            extAmountIn: F.e(10),
            forTxReward: F.e(2),
            forUtxoReward: F.e(3),
            forDepositReward: F.e(4),
            rAmountTips: F.e(2),
            amountsIn: [F.e(2), F.e(4)],
            createTimes: [F.e(10), F.e(15)],
            spendTime: F.e(20),
            assetWeight: F.e(2),
        };
        let S3 = 0n;
        let S1 = input.forTxReward;
        let S2 = input.forDepositReward * input.extAmountIn;
        for (var i = 0; i < input.amountsIn.length; i++) {
            S3 += BigInt(
                input.amountsIn[i] * (input.spendTime - input.createTimes[i]),
            );
        }
        let S4 = S3 * input.forUtxoReward;
        let S5 = (S4 + BigInt(S2)) * input.assetWeight;
        let R = S1 + S5;

        const rAmountTips = input.rAmountTips;
        const rAmount = R - rAmountTips;

        const w = await circuitRewards.calculateWitness(input, true);

        await circuitRewards.assertOut(w, {rAmount: rAmount});
    });
});
