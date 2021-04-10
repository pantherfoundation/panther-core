//SPDX-License-Identifier: ISC

include "../../node_modules/circomlib/circuits/poseidon.circom";


template NoteHasher(){
    signal input spendPbkX;
    signal input spendPbkY;
    signal input amount;
    signal input token;
    signal input createTime;

    signal output out;

    component noteHasher = Poseidon(5);

    noteHasher.inputs[0] <== spendPbkX;
    noteHasher.inputs[1] <== spendPbkY;
    noteHasher.inputs[2] <== amount;
    noteHasher.inputs[3] <== token;
    noteHasher.inputs[4] <== createTime;

    noteHasher.out ==> out;
}
