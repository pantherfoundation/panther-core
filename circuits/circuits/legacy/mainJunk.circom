//SPDX-License-Identifier: ISC
pragma circom 2.1.6;
// include "./templates/utils.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

template UintTag(isActive, nBits) {
    signal input in;
    signal output {uint} out;

    assert(nBits <= 252);

    component n2b;
    if ( isActive ) {
        n2b = Num2Bits(nBits);
        n2b.in <== in;
    }
    out <== in;
}

template OR() {
    signal input a;
    signal input b;
    signal output {uint96} out;

    signal p1 <== UintTag(1,96)(a);
    signal p2 <== UintTag(1,96)(b);
    out <== p1 + p2;
}

template mainOR() {
    signal input a;

    signal or <== OR()(a,a);

}
component main { public [a] } = mainOR();
