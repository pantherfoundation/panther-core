//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZZoneNoteHasher(){
    signal input zoneId;                                   // 16
    signal input edDsaPubKey[2];                           // 256
    signal input originZoneIDs;                            // 256
    signal input targetZoneIDs;                            // 256
    signal input networkIDsBitMap;                         // 64
    signal input kycKytMerkleTreeLeafIDsAndRulesList;      // 256
    signal input kycExpiryTime;                            // 32
    signal input kytExpiryTime;                            // 32
    signal input depositMaxAmount;                         // 64
    signal input withdrawMaxAmount;                        // 64
    signal input internalMaxAmount;                        // 64
    signal input zAccountIDsBlackList;                     // 256
    signal input maximumAmountPerTimePeriod;               // 256
    signal input timePeriodPerMaximumAmount;               // 32 bit

    signal output out;

    component hash = Poseidon(15);
    hash.inputs[0] <== zoneId;
    hash.inputs[1] <== edDsaPubKey[0];
    hash.inputs[2] <== edDsaPubKey[1];
    hash.inputs[3] <== originZoneIDs;
    hash.inputs[4] <== targetZoneIDs;
    hash.inputs[5] <== networkIDsBitMap;
    hash.inputs[6] <== kycKytMerkleTreeLeafIDsAndRulesList;
    hash.inputs[7] <== kycExpiryTime;
    hash.inputs[8] <== kytExpiryTime;
    hash.inputs[9] <== depositMaxAmount;
    hash.inputs[10] <== withdrawMaxAmount;
    hash.inputs[11] <== internalMaxAmount;
    hash.inputs[12] <== zAccountIDsBlackList;
    hash.inputs[13] <== maximumAmountPerTimePeriod;
    hash.inputs[14] <== timePeriodPerMaximumAmount;

    hash.out ==> out;
    /*
    component b2n_0 = Bits2Num(16+32+32+64+32); // 144+32 = 176

    component n2b_zoneId = Num2Bits(16);
    n2b_zoneId.in <== zoneId;

    for(var i = 16; i > 0; i--) {
        b2n_0.in[176-i] <== n2b_zoneId.out[16-i];
    }

    component n2b_KycExpiryTime = Num2Bits(32);
    n2b_KycExpiryTime.in <== kycExpiryTime;

    for(var i = 32; i > 0; i--) {
        b2n_0.in[176-16-i] <== n2b_KycExpiryTime.out[32-i];
    }

    component n2b_KytExpiryTime = Num2Bits(32);
    n2b_KytExpiryTime.in <== kytExpiryTime;

    for(var i = 32; i > 0; i--) {
        b2n_0.in[176-16-32-i] <== n2b_KytExpiryTime.out[32-i];
    }

    component n2b_networkIDsBitMap = Num2Bits(64);
    n2b_networkIDsBitMap.in <== networkIDsBitMap;

    for(var i = 64; i > 0; i--) {
        b2n_0.in[176-16-32-32-i] <== n2b_networkIDsBitMap.out[64-i];
    }

    component n2b_timePeriodPerMaximumAmount = Num2Bits(32);
    n2b_timePeriodPerMaximumAmount.in <== timePeriodPerMaximumAmount;

    for(var i = 32; i > 0; i--) {
        b2n_0.in[176-16-32-32-64-i] <== n2b_timePeriodPerMaximumAmount.out[32-i];
    }

    component b2n_1 = Bits2Num(64+64+64); // 196

    component n2b_DepositMaxAmount  = Num2Bits(64);
    n2b_DepositMaxAmount.in <== depositMaxAmount;

    for(var i = 64; i > 0; i--) {
        b2n_1.in[192-i] <== n2b_DepositMaxAmount.out[64-i];
    }

    component n2b_WithrawalMaxAmount  = Num2Bits(64);
    n2b_WithrawalMaxAmount.in <== withdrawMaxAmount;

    for(var i = 64; i > 0; i--) {
        b2n_1.in[192-64-i] <== n2b_WithrawalMaxAmount.out[64-i];
    }

    component n2b_InternalMaxAmount  = Num2Bits(64);
    n2b_InternalMaxAmount.in <== internalMaxAmount;

    for(var i = 64; i > 0; i--) {
        b2n_1.in[192-64-64-i] <== n2b_InternalMaxAmount.out[64-i];
    }

    component hash0 = Poseidon(5);
    hash0.inputs[0] <== originZoneIDs;
    hash0.inputs[1] <== targetZoneIDs;
    hash0.inputs[2] <== kycKytMerkleTreeLeafIDsAndRulesList;
    hash0.inputs[3] <== b2n_0.out;
    hash0.inputs[4] <== b2n_1.out;

    component hash1 = Poseidon(4);
    hash1.inputs[0] <== edDsaPubKey[0];
    hash1.inputs[1] <== edDsaPubKey[1];
    hash1.inputs[2] <== maximumAmountPerTimePeriod;
    hash1.inputs[3] <== hash0.out;

    hash1.out ==> out;
    */
}

