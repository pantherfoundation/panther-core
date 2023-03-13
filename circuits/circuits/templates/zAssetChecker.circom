//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";

template ZAssetChecker() {
    signal input publicZAsset;
    signal input privateZAsset;
    signal input depositAmount;
    signal input withdrawAmount;
    signal output isZkpToken;

    // `publicZAsset` must be zero if `externalAmounts == 0`, or `token` otherwise
    var extAmounts = depositAmount + withdrawAmount;

    component isZero = IsZero();
    isZero.in <== extAmounts;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== publicZAsset;
    isEqual.in[1] <== privateZAsset;
    isEqual.enabled <== 1-isZero.out;

    // TODO: FIXME - put real zZKP token
    var zZKP = 0;

    component isZkpTokenEqual = IsEqual();
    isZkpTokenEqual.in[0] <== privateZAsset;
    isZkpTokenEqual.in[1] <== zZKP;

    isZkpToken <== isZkpTokenEqual.out;
}
