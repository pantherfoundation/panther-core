//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

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

template NoteHasherPacked(){
    signal input spendPk[2];
    signal input amount;
    signal input token;
    signal input createTime;

    signal output out;

    // 64-bit-amount | 160-bit-token | 32-bit-createTime
    component b2n_amount_token_createTime = Bits2Num(256);

    component n2b_amount = Num2Bits(64);
    n2b_amount.in <== amount;

    for(var i = 64; i > 0; i--) {
        b2n_amount_token_createTime.in[256-i] <== n2b_amount.out[64-i];
    }

    component n2b_token = Num2Bits(160);
    n2b_token.in <== token;

    for(var i = 160; i > 0; i--) {
        b2n_amount_token_createTime.in[256-64-i] <== n2b_token.out[160-i];
    }

    component n2b_createTime = Num2Bits(32);
    n2b_createTime.in <== createTime;

    for(var i = 32; i > 0; i--) {
        b2n_amount_token_createTime.in[256-64-160-i] <== n2b_createTime.out[32-i];
    }

    component noteHasher = Poseidon(3);

    noteHasher.inputs[0] <== spendPk[0];
    noteHasher.inputs[1] <== spendPk[1];
    noteHasher.inputs[2] <== b2n_amount_token_createTime.out;

    noteHasher.out ==> out;
}
