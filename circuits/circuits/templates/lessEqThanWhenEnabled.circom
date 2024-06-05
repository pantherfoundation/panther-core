//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

// Checks if the first input signal is lesser than or equal to the second input signal when input signal enabled is true.
template LessEqThanWhenEnabled(n){
    signal input enabled;
    signal input in[2];

    component lt = LessEqThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1]+1;

    lt.out * enabled === 0;
}
