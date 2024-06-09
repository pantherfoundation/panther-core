//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./isNotZero.circom";

include "../../node_modules/circomlib/circuits/comparators.circom";

// Checks if the first input signal is lesser than or equal to the second input signal when input signal enabled is true.
template LessEqThanWhenEnabled(n){
    signal input enabled;
    signal input in[2];

    // 0 - when 2 <= 3, 1 - when 1 <= 1 or 2
    component lt = LessEqThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    // 1 - when `enabled > 0`, 0 - when `enabled == 0`
    component isNotZero = IsNotZero();
    isNotZero.in <== enabled;

    // when `enabled != 0` it will require `in[0] <= in[1]`
    // when `enabled == 0` it will nullify equation from both sides
    lt.out * isNotZero.out === 1 * isNotZero.out;
}

template ForceLessEqThan(n){
    signal input in[2];

    component lt = LessEqThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    // always require `in[0] <= in[1]`
    lt.out === 1;
}
