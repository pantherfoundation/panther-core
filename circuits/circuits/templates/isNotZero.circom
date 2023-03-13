//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";

template IsNotZero(){
    signal input in;
    signal output out;
    component isZero = IsZero();
    isZero.in <== in;
    out <== 1 - isZero.out;
}
