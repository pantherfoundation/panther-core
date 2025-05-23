// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZoneIdInclusionProver(){
    signal input enabled;
    signal input {uint16} zoneId;  // 16 bit
    signal input zoneIds;          // 240 bit
    signal input {uint4} offset;   // 4 bit

    assert(offset < 15);
    component offset_lessThan_15 = LessThan(4);
    offset_lessThan_15.in[0] <== offset;
    offset_lessThan_15.in[1] <== 15;
    offset_lessThan_15.out === 1;

    component n2b_zoneIds = Num2Bits(240);
    n2b_zoneIds.in <== zoneIds;

    component b2n_zoneIds[15];

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
