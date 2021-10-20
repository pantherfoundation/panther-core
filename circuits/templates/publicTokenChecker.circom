//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";


template PublicTokenChecker() {
    signal input publicToken;
    signal input token;
    signal input extAmounts;

    // `publicToken` must be zero if `extAmounts == 0`, or `token` otherwise
    signal output out; // 1 if the condition is true


    component isZero = IsZero();
    isZero.in <== extAmounts;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== publicToken;
    isEqual.in[1] <== token;
    isEqual.enabled <== 1-iSZero.out;

    out <== isEqual.out;
}
