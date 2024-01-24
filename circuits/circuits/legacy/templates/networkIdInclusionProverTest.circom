//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template NetworkIdInclusionProverTest(){
    signal input enabled;
    signal input networkId;         // 6 bit - power of 2
    signal input networkIdsBitMap;  // 64 bit

    // [0] - Check only single bit is up
    // assert(networkId & (networkId-1) == 0);
    assert(networkId < 64);
    signal t1;
    t1 <-- 1 << networkId;

    // [1] - Inclusion proof
    component and = AND();
    and.a <== t1;
    and.b <== networkIdsBitMap;

    component isZero = IsZero();
    isZero.in <== and.out;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== isZero.out;
    isEqual.in[1] <== 0;
    isEqual.enabled <== enabled;
}
