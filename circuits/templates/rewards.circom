//SPDX-License-Identifier: ISC
pragma circom 2.0.0;
include "../../node_modules/circomlib/circuits/comparators.circom";

template Rewards(nUtxoIn) {
    signal input extAmountIn;
    signal input forTxReward;
    signal input forUtxoReward;
    signal input forDepositReward;
    signal input rAmountTips;
    signal input spendTime;
    signal input assetWeight;
    signal input amountsIn[nUtxoIn];
    signal input createTimes[nUtxoIn];

    

    signal output rAmount;

    /*
    R = forTxReward + (
      forUtxoReward * sum[over i](UTXO_period_i * UTXO_amount_i) + forDepositReward * deposit_amount
    ) * asset_weight
    S1 = forTxReward
    S2 = forDepositReward * deposit_amount
    S3 = sum[over i](UTXO_period_i * UTXO_amount_i)
    S4 = forUtxoReward * S3
    S5 = (S4 + S2)*assetWeight
    R = S1 + S5
    */

    signal S1;
    signal S2;
    signal S3;
    signal S4;
    signal S5;
    signal R;
    S1 <== forTxReward;
    S2 <== forDepositReward * extAmountIn;
    signal sum[nUtxoIn];
    sum[0] <== (spendTime - createTimes[0]) * amountsIn[0];
    for(var i=1; i<nUtxoIn; i++) {
        sum[i] <== sum[i-1] + (spendTime - createTimes[i]) * amountsIn[i];
    }
    S3 <== sum[nUtxoIn-1];
    S4 <== forUtxoReward*S3;
    S5 <== (S4 + S2) * assetWeight;
    R <== S1 + S5;

    component lte = LessEqThan(120); // assuming R and rAmountTips are 120-bits
    lte.in[0] <== rAmountTips;
    lte.in[1] <== R;
    lte.out === 1;
    rAmount <== R - rAmountTips;
}
