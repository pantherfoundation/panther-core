//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZoneIdInclusionProverTest(){
    signal input enabled;
    signal input zoneId;   // 16 bit
    signal input zoneIds;  // 256 bit
    signal input offset;   // 4 bit

    assert(offset < 16);

    component n2b = Num2Bits(16);
    signal temp;
    temp <-- zoneIds >> offset;
    signal temp1 <-- temp & ((1<<16)-1);
    n2b.in <== temp1;

    component b2nZoneId = Bits2Num(16);
    for (var i = 0; i < 16; i++) {
        b2nZoneId.in[i] <== n2b.out[i];
    }

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== zoneId;
    isEqual.in[1] <== b2nZoneId.out;
    isEqual.enabled <== enabled;
}
