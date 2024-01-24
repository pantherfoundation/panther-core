//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZoneIdInclusionProver(){
    signal input enabled;
    signal input zoneId;   // 16 bit
    signal input zoneIds;  // 256 bit
    signal input offset;   // 4 bit

    assert(offset < 16);

    component n2b_zoneIds = Num2Bits(254);
    n2b_zoneIds.in <== zoneIds;

    component b2n_zoneIds[16];

    for(var i = 0, ii = 0; i < 15*16; i += 16) {
        b2n_zoneIds[ii] = Bits2Num(16);
        for ( var j = 0; j < 16; j++) {
            b2n_zoneIds[ii].in[j] <== n2b_zoneIds.out[i + j];
        }
        ii++;
    }

    component forceIsEqual[15];
    component is_equal[15];
    for(var i = 0; i < 15; i++) {
        is_equal[i] = IsEqual();
        is_equal[i].in[0] <== i;
        is_equal[i].in[1] <== offset;

        forceIsEqual[i] = ForceEqualIfEnabled();
        forceIsEqual[i].in[0] <== zoneId;
        forceIsEqual[i].in[1] <== b2n_zoneIds[i].out;
        // i == offset this is the exact portion of bits to check
        forceIsEqual[i].enabled <== enabled * is_equal[i].out;
    }
}
