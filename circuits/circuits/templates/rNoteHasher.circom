//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";


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

template RNoteHasherPacked(){
    signal input spendPk[2];
    signal input amount;
    signal input nonce;

    signal output out;

    // 64-bit-amount | 64-bit-nonce
    component b2n_amount_nonce = Bits2Num(128);

    component n2b_amount = Num2Bits(64);
    n2b_amount.in <== amount;

    for(var i = 64; i > 0; i--) {
        b2n_amount_nonce.in[128-i] <== n2b_amount.out[64-i];
    }

    component n2b_nonce = Num2Bits(64);
    n2b_nonce.in <== nonce;

    for(var i = 64; i > 0; i--) {
        b2n_amount_nonce.in[128-64-i] <== n2b_nonce.out[64-i];
    }

    component noteHasher = Poseidon(3);

    noteHasher.inputs[0] <== spendPk[0];
    noteHasher.inputs[1] <== spendPk[1];
    noteHasher.inputs[2] <== b2n_amount_nonce.out;

    noteHasher.out ==> out;
}
