//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

/*
This template checks if the given ZAccount in a ZZone is not blacklisted.

@input signals -
1. zAccountId - unique zAccountId for a ZAccount
2. zAccountIDsBlackList - List of all ZAccounts that are blacklisted.
*/
template ZZoneZAccountBlackListExclusionProver(){
    signal input {uint24}  zAccountId;              // 24 bit
    signal input {uint240} zAccountIDsBlackList;    // 10 x 24 bit at most

    assert(zAccountId < 2**24);

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

        // require exclusion
        isEqual[i].out === 0;
    }
}
