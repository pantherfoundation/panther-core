//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

template RangeCheck(N, RC) {
    signal input in[N];

    component lessThen[N];
    component greaterThen[N];
    for ( var i = 0; i < N; i++ ) {
        lessThen[i] = LessThan(RC);
        lessThen[i].in[0] <== in[i];
        lessThen[i].in[1] <== 2**RC;
        lessThen[i].out === 1;

        greaterThen[i] = GreaterThan(RC);
        greaterThen[i].in[0] <== 0;
        greaterThen[i].in[1] <== in[i];
        greaterThen[i].out === 1;
    }
}

template RangeCheckSingleSignal(LessThanValue, LessThanBits, GreaterThanValue, GreaterThanBits) {
    signal input in;

    component less;
    less = LessThan(LessThanBits);
    less.in[0] <== in[i];
    less.in[1] <== LessThanValue;
    less.out === 1;

    component greater;
    greater = GreaterThan(GreaterThanBits);
    greater.in[0] <== GreaterThanValue;
    greater.in[1] <== in[i];
    greater.out === 1;
}
