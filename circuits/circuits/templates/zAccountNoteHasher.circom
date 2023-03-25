// SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZAccountNoteHasher(){
    signal input spendPubKey[2];            // 2 x 256 bit
    signal input rootSpendPubKey[2];        // 2 x 256 bit
    signal input masterEOA;                 // 160 bit
    signal input id;                        // 24 bit
    signal input amountZkp;                 // 64 bit
    signal input amountPrp;                 // 64 bit
    signal input zoneId;                    // 16 bit
    signal input expiryTime;                // 32 bit
    signal input nonce;                     // 16 bit
    signal input totalAmountPerTimePeriod;  // 256 bit
    signal input createTime;                // 32 bit
    signal input networkId;                 // 6 bit

    signal output out;

    component hash = Poseidon(14);

    hash.inputs[0] <== spendPubKey[0];
    hash.inputs[1] <== spendPubKey[1];
    hash.inputs[2] <== rootSpendPubKey[0];
    hash.inputs[3] <== rootSpendPubKey[1];
    hash.inputs[4] <== masterEOA;
    hash.inputs[5] <== id;
    hash.inputs[6] <== amountZkp;
    hash.inputs[7] <== amountPrp;
    hash.inputs[8] <== zoneId;
    hash.inputs[9] <== expiryTime;
    hash.inputs[10] <== nonce;
    hash.inputs[11] <== totalAmountPerTimePeriod;
    hash.inputs[12] <== createTime;
    hash.inputs[13] <== networkId;

    out <== hash.out;

    /* OLD CODE
    // MSB to LSB
    // id [24]
    // + amountZkp [64]
    // + amountPrp [64]
    // + zoneId [16]
    // + expiryTime [32]
    // + nonce [16]
    // + createTime [32]
    // + networkId [6] = 254
    component b2n_zero = Bits2Num(254);

    // [0] - id
    component n2b_id = Num2Bits(24);
    n2b_id.in <== id;

    var shift = 248;
    for(var i = 24; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_id.out[24-i];
    }
    // [1] - amountZkp
    component n2b_amountZkp = Num2Bits(64);
    n2b_amountZkp.in <== amountZkp;

    shift -= 24;
    for(var i = 64; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_amountZkp.out[64-i];
    }
    // [2] - amountPrp
    component n2b_amountPrp = Num2Bits(64);
    n2b_amountPrp.in <== amountPrp;

    shift -= 64;
    for(var i = 64; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_amountPrp.out[64-i];
    }
    // [3] - zoneId
    component n2b_zoneId = Num2Bits(16);
    n2b_zoneId.in <== zoneId;

    shift -= 64;
    for(var i = 16; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_zoneId.out[16-i];
    }
    // [4] - expiryTime
    component n2b_expiryTime = Num2Bits(32);
    n2b_expiryTime.in <== expiryTime;

    shift -= 16;
    for(var i = 32; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_expiryTime.out[32-i];
    }
    // [5] - nonce
    component n2b_nonce = Num2Bits(16);
    n2b_nonce.in <== nonce;

    shift -= 32;
    for(var i = 16; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_nonce.out[16-i];
    }

    // [6] - createTime
    component n2b_createTime = Num2Bits(32);
    n2b_createTime.in <== createTime;

    shift -= 16;
    for(var i = 32; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_createTime.out[32-i];
    }

    // [7] - networkId
    component n2b_networkId = Num2Bits(6);
    n2b_networkId.in <== networkId;

    shift -= 32;
    for(var i = 6; i > 0; i--) {
        b2n_zero.in[shift-i] <== n2b_networkId.out[6-i];
    }

    // [8] - Hasher-0
    component hasher0 = Poseidon(5);

    hasher0.inputs[0] <== spendPubKey[0];
    hasher0.inputs[1] <== spendPubKey[1];
    hasher0.inputs[2] <== rootSpendPubKey[0];
    hasher0.inputs[3] <== rootSpendPubKey[1];
    hasher0.inputs[4] <== masterEOA;

    // [9] - Top hasher
    component topHasher = Poseidon(3);
    topHasher.inputs[0] <== hasher0.out;
    topHasher.inputs[1] <== totalAmountPerTimePeriod;
    topHasher.inputs[2] <== b2n_zero.out;

    // [10] - Output
    out <== topHasher.out;

    */
}


template ZAccountNoteHasher2(){
    signal input spendPk[2];     // 2 x 256 bit
    signal input rootSpendPk[2]; // 2 x 256 bit
    signal input masterEOA;      // 160 bit

    // Leaf:
    //signal input id;             // 24 bit
    //signal input amountZkp;      // 64 bit
    //signal input amountPrp;      // 64 bit
    //signal input zoneId;         // 16 bit
    //signal input expiryTime;     // 32 bit
    //signal input nonce;          // 16 bit
    signal input leaf;             // 216 bit

    signal output out;

    // [0] - Hasher-0
    component hasher = Poseidon(5);

    hasher.inputs[0] <== spendPk[0];
    hasher.inputs[1] <== spendPk[1];
    hasher.inputs[2] <== rootSpendPk[0];
    hasher.inputs[3] <== rootSpendPk[1];
    hasher.inputs[4] <== masterEOA;

    // [1] - Top hasher
    component topHasher = Poseidon(2);
    topHasher.inputs[0] <== hasher.out;
    topHasher.inputs[1] <== leaf;

    // [2] - Output
    out <== topHasher.out;
}
