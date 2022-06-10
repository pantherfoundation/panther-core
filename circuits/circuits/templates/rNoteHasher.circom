//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";


template RNoteHasher(){
    signal input spendPk[2];
    signal input amount;

    signal output out;

    component noteHasher = Poseidon(3);

    noteHasher.inputs[0] <== spendPk[0];
    noteHasher.inputs[1] <== spendPk[1];
    noteHasher.inputs[2] <== amount;

    noteHasher.out ==> out;
}
