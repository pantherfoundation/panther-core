//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";

template ZAccountNullifierHasher(){
    signal input spendPrivKey;
    signal input commitment;

    signal output out;

    component noteHasher = Poseidon(2);

    noteHasher.inputs[0] <== spendPrivKey;
    noteHasher.inputs[1] <== commitment;

    noteHasher.out ==> out;
}
