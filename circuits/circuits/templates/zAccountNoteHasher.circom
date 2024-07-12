// SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZAccountNoteHasher(){
    signal input {sub_order_bj_p}  spendPubKey[2];             // 2 x 254 bit
    signal input {sub_order_bj_p}  rootSpendPubKey[2];         // 2 x 254 bit
    signal input {sub_order_bj_p}  readPubKey[2];              // 2 x 254 bit
    signal input {sub_order_bj_p}  nullifierPubKey[2];         // 2 x 254 bit
    signal input {uint160}         masterEOA;                  // 160 bit
    signal input {uint24}          id;                         // 24 bit
    signal input {uint64}          amountZkp;                  // 252 bit
    signal input {uint196}         amountPrp;                  // 196 bit
    signal input {uint16}          zoneId;                     // 16 bit
    signal input {uint32}          expiryTime;                 // 32 bit
    signal input {uint32}          nonce;                      // 32 bit
    signal input {uint96}          totalAmountPerTimePeriod;   // 96 bit
    signal input {uint32}          createTime;                 // 32 bit
    signal input {uint6}           networkId;                  // 6 bit

    signal output out;

    component hash1 = Poseidon(8);

    hash1.inputs[0] <== spendPubKey[0];
    hash1.inputs[1] <== spendPubKey[1];
    hash1.inputs[2] <== rootSpendPubKey[0];
    hash1.inputs[3] <== rootSpendPubKey[1];
    hash1.inputs[4] <== readPubKey[0];
    hash1.inputs[5] <== readPubKey[1];
    hash1.inputs[6] <== nullifierPubKey[0];
    hash1.inputs[7] <== nullifierPubKey[1];

    component hash = Poseidon(11);
    hash.inputs[0] <== hash1.out;
    hash.inputs[1] <== masterEOA;
    hash.inputs[2] <== id;
    hash.inputs[3] <== amountZkp;
    hash.inputs[4] <== amountPrp;
    hash.inputs[5] <== zoneId;
    hash.inputs[6] <== expiryTime;
    hash.inputs[7] <== nonce;
    hash.inputs[8] <== totalAmountPerTimePeriod;
    hash.inputs[9] <== createTime;
    hash.inputs[10] <== networkId;

    out <== hash.out;
}
