//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/escalarmulany.circom";

template NullifierHasher(){
    signal input privKey;
    signal input leaf;

    signal output out;

    component noteHasher = Poseidon(2);

    noteHasher.inputs[0] <== privKey;
    noteHasher.inputs[1] <== leaf;

    noteHasher.out ==> out;
}

template NullifierHasherExtended() {
    signal input {sub_order_bj_sf} privKey;
    signal input {sub_order_bj_p}  pubKey[2];
    signal input leaf;

    signal output out;

    component sharedSecret = NullifierSharedSecret();
    sharedSecret.privKey <== privKey;
    sharedSecret.pubKey[0] <== pubKey[0];
    sharedSecret.pubKey[1] <== pubKey[1];

    component noteHasher = Poseidon(3);

    noteHasher.inputs[0] <== sharedSecret.sharedKey[0];
    noteHasher.inputs[1] <== sharedSecret.sharedKey[1];
    noteHasher.inputs[2] <== leaf;

    noteHasher.out ==> out;
}

template NullifierSharedSecret() {
    signal input privKey;
    signal input pubKey[2];
    signal output sharedKey[2];

    component n2b = Num2Bits(253);
    component drv = EscalarMulAny(253);

    n2b.in <== privKey;

    drv.p[0] <== pubKey[0];
    drv.p[1] <== pubKey[1];

    for (var j = 0; j < 253; j++) {
        drv.e[j] <== n2b.out[j];
    }

    sharedKey[0] <== drv.out[0];
    sharedKey[1] <== drv.out[1];
}
