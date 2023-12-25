//SPDX-License-Identifier: ISC
pragma circom 2.1.6;
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template RewardsExtended(nUtxoIn) {
    signal input depositAmount;             // 64 bit
    signal input forTxReward;               // 40 bit
    signal input forUtxoReward;             // 40 bit
    signal input forDepositReward;          // 40 bit
    signal input spendTime;                 // 32 bit
    signal input assetWeight;               // 32 bit
    signal input utxoInAmount[nUtxoIn];     // 64 bit
    signal input utxoInCreateTime[nUtxoIn]; // 64 bit

    signal output amountPrp;

    /*
     * R = forTxReward
     *   + [ forUtxoReward * sum[over i] ( UTXO_period_i * UTXO_amount_i )
             + forDepositReward * deposit_amount ] * asset_weight
     * S1 = forTxReward
     * S2 = forDepositReward * deposit_amount
     * S3 = sum[over i](UTXO_period_i * UTXO_amount_i)
     * S4 = forUtxoReward * S3
     * S5 = (S4 + S2)*assetWeight
     * R = S1 + S5
     */

    signal S1;
    signal S2;
    signal S3;
    signal S4;
    signal S5;
    signal R;
    S1 <== forTxReward;
    S2 <== forDepositReward * depositAmount;
    signal sum[nUtxoIn];
    component lessThen[nUtxoIn];
    lessThen[0] = LessThan(32);
    lessThen[0].in[0] <== spendTime;
    lessThen[0].in[1] <== utxoInCreateTime[0];
    signal mult[nUtxoIn];
    mult[0] <== lessThen[0].out * (spendTime - utxoInCreateTime[0]);
    sum[0] <==  mult[0] * utxoInAmount[0];
    for (var i = 1; i < nUtxoIn; i++) {
        // if spendTime < createTime --> spendTime - createTime = 0
        // so sum[i] <== sum[i-1];
        lessThen[i] = LessThan(32);
        lessThen[i].in[0] <== spendTime;
        lessThen[i].in[1] <== utxoInCreateTime[i];
        mult[i] <== lessThen[i].out * (spendTime - utxoInCreateTime[i]);
        sum[i] <== sum[i-1] + mult[i] * utxoInAmount[i];
    }
    S3 <== sum[nUtxoIn-1];
    S4 <== forUtxoReward * S3;
    S5 <== (S4 + S2) * assetWeight;
    R <== S1 + S5;

    var prpScaleFactor = 60;
    component n2b = Num2Bits(253);
    n2b.in <== R;

    component b2n = Bits2Num(253-prpScaleFactor);
    for (var i = prpScaleFactor; i < 253; i++) {
        b2n.in[i-prpScaleFactor] <== n2b.out[i];
    }

    amountPrp <== b2n.out;
}
