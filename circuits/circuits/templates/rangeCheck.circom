//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/comparators.circom";

template RangeCheckGroupOfSignals(N, maxBits, LessThanValue, GreaterThanValue) {
    signal input in[N];

    component lessThen[N];
    component greaterThen[N];
    for ( var i = 0; i < N; i++ ) {
        lessThen[i] = LessThan(maxBits);
        lessThen[i].in[0] <== in[i];
        lessThen[i].in[1] <== LessThanValue;
        lessThen[i].out === 1;

        greaterThen[i] = GreaterThan(maxBits);
        greaterThen[i].in[0] <== GreaterThanValue;
        greaterThen[i].in[1] <== in[i];
        greaterThen[i].out === 1;
    }
}

template RangeCheckSingleSignal(maxBits, LessThanValue, GreaterThanValue) {
    signal input in;
    component less = LessThan(maxBits);
    less.in[0] <== in;
    less.in[1] <== LessThanValue;
    less.out === 1;

    component greater = GreaterThan(maxBits);
    greater.in[0] <== GreaterThanValue;
    greater.in[1] <== in;
    greater.out === 1;
}
