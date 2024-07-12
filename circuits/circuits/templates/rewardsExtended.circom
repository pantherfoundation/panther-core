//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./utils.circom";

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

///*
// * R = forTxReward
// *   + [ forUtxoReward * sum[over i] ( UTXO_period_i * UTXO_amount_i )
//         + forDepositReward * deposit_amount ] * asset_weight
// * S1 = forTxReward
// * S2 = forDepositReward * deposit_amount
// * S3 = sum[over i](UTXO_period_i * UTXO_amount_i)
// * S4 = forUtxoReward * S3
// * S5 = (S4 + S2)*assetWeight
// * R = S1 + S5
// */
template RewardsExtended(nUtxoIn) {
    signal input {uint96}          depositAmount;
    signal input {uint40}          forTxReward;
    signal input {uint40}          forUtxoReward;
    signal input {uint40}          forDepositReward;
    signal input {uint32}          spendTime;
    signal input {non_zero_uint32} assetWeight;
    signal input {uint64}          utxoInAmount[nUtxoIn];
    signal input {uint32}          utxoInCreateTime[nUtxoIn];

    signal output {uint196}        amountPrp;

    signal S1;
    signal S2;
    signal S3;
    signal S4;
    signal S5;
    signal R;

    assert(spendTime <= 2**32);
    assert(utxoInCreateTime[0] <= 2**32);

    var prpScaleFactor = 60;
    S1 <== forTxReward * (2 ** prpScaleFactor); // 2^40 x 2^60 = 2^100
    S2 <== forDepositReward * depositAmount;    // 2^40 x 2^96 = 2^136
    signal sum[nUtxoIn];
    component lessThen[nUtxoIn];
    lessThen[0] = LessThan(32);
    lessThen[0].in[0] <== utxoInCreateTime[0];
    lessThen[0].in[1] <== spendTime;
    signal mult[nUtxoIn];
    mult[0] <== lessThen[0].out * (spendTime - utxoInCreateTime[0]); // 2^32
    sum[0] <==  mult[0] * utxoInAmount[0]; // 2^32 x 2^64 = 2^96
    for (var i = 1; i < nUtxoIn; i++) {
        // if spendTime < createTime --> spendTime - createTime = 0
        // so sum[i] <== sum[i-1];

        assert(utxoInCreateTime[i] <= 2**32);
        lessThen[i] = LessThan(32);
        lessThen[i].in[0] <== utxoInCreateTime[i];
        lessThen[i].in[1] <== spendTime;
        // can't be negative
        mult[i] <== lessThen[i].out * (spendTime - utxoInCreateTime[i]);
        // can't overflow
        sum[i] <== sum[i-1] + mult[i] * utxoInAmount[i]; // nUtxoIn x 2^96 + 2^96
    }
    S3 <== sum[nUtxoIn-1]; // ~ 2^100
    S4 <== forUtxoReward * S3; // 2^40 x 2^100 = 2^140
    S5 <== (S4 + S2) * assetWeight; // 2^141 x 2^32 = 2^173
    R <== S1 + S5; // 2^100 + 2^173 = 2^174 (at most)

    component n2b = Num2Bits(253);
    n2b.in <== R;

    component b2n = Bits2Num(253-prpScaleFactor);
    for (var i = prpScaleFactor; i < 253; i++) {
        b2n.in[i-prpScaleFactor] <== n2b.out[i];
    }
    // at most 2^(253 - 60) = 2^196
    assert(253 - prpScaleFactor < 196);
    var ACTIVE = Active();
    amountPrp <== Uint196Tag(ACTIVE)(b2n.out);
}
