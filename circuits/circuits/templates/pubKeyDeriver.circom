//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/escalarmulany.circom";

template PubKeyDeriver(){
    signal input rootPubKey[2];
    signal input random;
    signal output derivedPubKey[2];

    component n2b = Num2Bits(253);

    n2b.in <== random;

    component drv = EscalarMulAny(253);
    drv.p[0] <== rootPubKey[0];
    drv.p[1] <== rootPubKey[1];

    for (var i = 0; i < 253; i++) {
      drv.e[i] <== n2b.out[i];
    }

    derivedPubKey[0] <== drv.out[0];
    derivedPubKey[1] <== drv.out[1];
}
