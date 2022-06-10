//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";


template NoteHasher(){
    signal input spendPk[2];
    signal input amount;
    signal input token;
    signal input createTime;

    signal output out;

    component noteHasher = Poseidon(5);

    noteHasher.inputs[0] <== spendPk[0];
    noteHasher.inputs[1] <== spendPk[1];
    noteHasher.inputs[2] <== amount;
    noteHasher.inputs[3] <== token;
    noteHasher.inputs[4] <== createTime;

    noteHasher.out ==> out;
}
