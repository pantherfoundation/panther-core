//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./multiOR.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template ZZoneZAccountBlackListExclusionProver(){
    signal input zAccountId;              // 24 bit
    signal input zAccountIDsBlackList;    // 10 x 24 bit at most

    assert(zAccountId <= 2**24);

    component n2b = Num2Bits(10 * 24);
    n2b.in <== zAccountIDsBlackList;

    component isEqual[10];
    component b2n[10];

    for( var i = 0; i < 10; i++) {
        b2n[i] = Bits2Num(24);
        for(var j = 0; j < 24; j++) {
            b2n[i].in[j] <== n2b.out[i * 24 + j];
        }

        isEqual[i] = IsEqual();
        isEqual[i].in[0] <== zAccountId;
        isEqual[i].in[1] <== b2n[i].out;

        // require excusion
        isEqual[i].out === 0;
    }
}
