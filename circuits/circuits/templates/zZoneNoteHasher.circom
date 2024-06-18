//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template ZZoneNoteHasher(){
    signal input {uint16}  zoneId;                                        // 16
    signal input           edDsaPubKey[2];                                // 256
    signal input {uint16}  originZoneIDs;                                 // 256
    signal input {uint16}  targetZoneIDs;                                 // 256
    signal input {uint64}  networkIDsBitMap;                              // 64
    signal input           trustProvidersMerkleTreeLeafIDsAndRulesList;   // 256
    signal input {uint32}  kycExpiryTime;                                 // 32
    signal input {uint32}  kytExpiryTime;                                 // 32
    signal input           depositMaxAmount;                              // 64
    signal input           withdrawMaxAmount;                             // 64
    signal input           internalMaxAmount;                             // 64
    signal input {uint240} zAccountIDsBlackList;                          // 256
    signal input           maximumAmountPerTimePeriod;                    // 256
    signal input {uint32}  timePeriodPerMaximumAmount;                    // 32 bit
    signal input           dataEscrowPubKey[2];                           // 256
    signal input {binary}  sealing;                                       // 1 bit

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

