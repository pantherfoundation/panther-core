//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";

template NullifierHasher(){
    signal input privKey;
    signal input leaf;

    signal output out;

    component noteHasher = Poseidon(2);

    noteHasher.inputs[0] <== privKey;
    noteHasher.inputs[1] <== leaf;

    noteHasher.out ==> out;
}

template NullifierHasherExtended(){
    signal input privKey;
    signal input leaf;

    signal output out;

    component noteHasher = Poseidon(2);

    noteHasher.inputs[0] <== privKey;
    noteHasher.inputs[1] <== leaf;

    noteHasher.out ==> out;
}
