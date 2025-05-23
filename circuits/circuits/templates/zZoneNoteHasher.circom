// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZZoneNoteHasher(){
    signal input {uint16}           zoneId;                                        // 16
    signal input {sub_order_bj_p}   edDsaPubKey[2];                                // 256
    signal input {uint240}          originZoneIDs;                                 // 240
    signal input {uint240}          targetZoneIDs;                                 // 240
    signal input {uint64}           networkIDsBitMap;                              // 64
    signal input {uint240}          trustProvidersMerkleTreeLeafIDsAndRulesList;   // 240
    signal input {uint32}           kycExpiryTime;                                 // 32
    signal input {uint32}           kytExpiryTime;                                 // 32
    signal input {uint96}           depositMaxAmount;                              // 96
    signal input {uint96}           withdrawMaxAmount;                             // 96
    signal input {uint96}           internalMaxAmount;                             // 96
    signal input {uint240}          zAccountIDsBlackList;                          // 240
    signal input {uint96}           maximumAmountPerTimePeriod;                    // 96
    signal input {uint32}           timePeriodPerMaximumAmount;                    // 32 bit
    signal input {sub_order_bj_p}   dataEscrowPubKey[2];                           // 256
    signal input {binary}           sealing;                                       // 1 bit

    signal output out;

    component hash = Poseidon(15);
    hash.inputs[0] <== zoneId;
    hash.inputs[1] <== edDsaPubKey[0];
    hash.inputs[2] <== edDsaPubKey[1];
    hash.inputs[3] <== originZoneIDs;
    hash.inputs[4] <== targetZoneIDs;
    hash.inputs[5] <== networkIDsBitMap;
    hash.inputs[6] <== trustProvidersMerkleTreeLeafIDsAndRulesList;
    hash.inputs[7] <== kycExpiryTime;
    hash.inputs[8] <== kytExpiryTime;
    hash.inputs[9] <== depositMaxAmount;
    hash.inputs[10] <== withdrawMaxAmount;
    hash.inputs[11] <== internalMaxAmount;
    hash.inputs[12] <== zAccountIDsBlackList;
    hash.inputs[13] <== maximumAmountPerTimePeriod;
    hash.inputs[14] <== timePeriodPerMaximumAmount;

    component hash_out = Poseidon(4);
    hash_out.inputs[0] <== dataEscrowPubKey[0];
    hash_out.inputs[1] <== dataEscrowPubKey[1];
    hash_out.inputs[2] <== sealing;
    hash_out.inputs[3] <== hash.out;

    hash_out.out ==> out;
}

