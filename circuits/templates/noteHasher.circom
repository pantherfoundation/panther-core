//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";


template NoteHasher(){
    signal input spendPkX;
    signal input amount;
    signal input token;
    signal input createTime;

    signal output out;

    component noteHasher = Poseidon(4);

    noteHasher.inputs[0] <== spendPkX;
    noteHasher.inputs[1] <== amount;
    noteHasher.inputs[2] <== token;
    noteHasher.inputs[3] <== createTime;

    noteHasher.out ==> out;
}
