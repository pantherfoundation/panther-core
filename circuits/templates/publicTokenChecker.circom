//SPDX-License-Identifier: ISC

include "../../node_modules/circomlib/circuits/comparators.circom";


template PublicTokenChecker() {
    signal input publicToken;
    signal input token;
    signal input extAmounts;

    // `publicToken` must be zero if `extAmounts == 0`, or `token` otherwise
    signal output out; // 1 if the condition is true


    component isZero = IsZero();
    isZero.in <== extAmounts;

    var expected = token * (1 - isZero.out);

    component isEqual = IsEqual();
    isEqual.in[0] <== publicToken;
    isEqual.in[1] <== expected;

    out <== isEqual.out;
}
