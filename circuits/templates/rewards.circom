//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

template Rewards(nUtxoIn) {
    signal input extAmountIn;
    signal input forTxReward; 
    signal input forUtxoReward; 
    signal input forDepositReward; 
    signal input forBaseReward;
    signal input relayerTips;
    signal input amountsIn[nUtxoIn];
    signal input createTimes[nUtxoIn];

    signal input spendTime;
    signal input assetWeight;

    signal output userRewards;
    signal output relayerRewards;

    signal c1c3;
    c1c3 <== forTxReward + forBaseReward;
    signal sum[nUtxoIn];
    sum[0] <== (spendTime - createTimes[0]) * amountsIn[0];
    for(var i=1; i<nUtxoIn; i++) {
        sum[i] <== sum[i-1] + (spendTime - createTimes[i]) * amountsIn[i];
    }
    signal c2sum; 
    c2sum <== sum[nUtxoIn-1] * forUtxoReward;
    signal c2sumWeight;
    c2sumWeight <== c2sum * assetWeight;
    signal c1Weight;
    c1Weight <== c1c3 + c2sumWeight;
    signal c4Deposit;
    c4Deposit <== forDepositReward* extAmountIn;
    signal c4Weight;
    c4Weight <== c4Deposit * assetWeight;
    signal R;
    R <== c1Weight + c4Weight;

    userRewards <== R - relayerTips;
    relayerRewards <== forBaseReward + relayerTips; 
}
component main = Rewards(2);