//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./multiOR.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

// 2 Level hash, first level is private parameters, second level is quasi-private,
// since in generare-deposits api, spendPk, zAsset and amount are publicly know parameters
template UtxoNoteHasher(){
    signal input spendPk[2];      // 256
    signal input zAsset;          // 64
    signal input amount;          // 64
    signal input originNetworkId; // 6
    signal input targetNetworkId; // 6
    signal input createTime;      // 32
    signal input originZoneId;    // 16
    signal input targetZoneId;    // 16
    signal input zAccountId;      // 24

    signal output out;

    // 2 x 6-bit-networkId | 32-bit-createTime | 16-bit-origin-zone-id | 16-bit-target-zone-id
    assert(originNetworkId < 2**6);
    assert(targetNetworkId < 2**6);
    assert(createTime < 2**32);
    assert(originZoneId < 2**16);
    assert(targetZoneId < 2**16);
    assert(zAccountId < 2**24);

    component multiOR = MultiOR(6);
    multiOR.in[0] <-- zAccountId << 6 + 6 + 32 + 16 + 16;
    multiOR.in[1] <-- originNetworkId << 6 + 32 + 16 + 16;
    multiOR.in[2] <-- targetNetworkId << 32 + 16 + 16;
    multiOR.in[3] <-- createTime << 16 + 16;
    multiOR.in[4] <-- originZoneId << 16;
    multiOR.in[5] <-- targetZoneId << 0;

    component hiden_hash = Poseidon(1);
    hiden_hash.inputs[0] <== multiOR.out;

    // quasi-public hash - used for generate-deposits
    component hasher = Poseidon(5);

    hasher.inputs[0] <== spendPk[0];
    hasher.inputs[1] <== spendPk[1];
    hasher.inputs[2] <== zAsset;
    hasher.inputs[3] <== amount;

    hasher.inputs[4] <== hiden_hash.out;

    hasher.out ==> out;
}

template UtxoNoteTwoStageHasher(){
    signal input spendPk[2];      // 256
    signal input zAsset;          // 64
    signal input amount;          // 64
    signal input leaf;            // 256
    signal output out;

    // quasi-public hash - used for generate-deposits - second stage
    component hasher = Poseidon(5);

    hasher.inputs[0] <== spendPk[0];
    hasher.inputs[1] <== spendPk[1];
    hasher.inputs[2] <== zAsset;
    hasher.inputs[3] <== amount;

    hasher.inputs[4] <== leaf;

    hasher.out ==> out;
}

template UtxoNoteLeafHasher(){
    signal input originNetworkId; // 6
    signal input targetNetworkId; // 6
    signal input createTime;      // 32
    signal input originZoneId;    // 16
    signal input targetZoneId;    // 16
    signal input zAccountId;      // 24

    signal output out;

    // 2 x 6-bit-networkId | 32-bit-createTime | 16-bit-origin-zone-id | 16-bit-target-zone-id
    assert(originNetworkId < 2**6);
    assert(targetNetworkId < 2**6);
    assert(createTime < 2**32);
    assert(originZoneId < 2**16);
    assert(targetZoneId < 2**16);

    component multiOR = MultiOR(6);
    multiOR.in[0] <-- zAccountId << 6 + 6 + 32 + 16 + 16;
    multiOR.in[1] <-- originNetworkId << 6 + 32 + 16 + 16;
    multiOR.in[2] <-- targetNetworkId << 32 + 16 + 16;
    multiOR.in[3] <-- createTime << 16 + 16;
    multiOR.in[4] <-- originZoneId << 16;
    multiOR.in[5] <-- targetZoneId << 0;

    component hiden_hash = Poseidon(1);
    hiden_hash.inputs[0] <== multiOR.out;

    out <== hiden_hash.out;
}

template UtxoNoteGenericHasher(){
    signal input spendPk[2];      // 256
    signal input zAsset;          // 64
    signal input amount;          // 64
    signal input originNetworkId; // 6
    signal input targetNetworkId; // 6
    signal input createTime;      // 32
    signal input originZoneId;    // 16
    signal input targetZoneId;    // 16
    signal input zAccountId;      // 24

    signal output out;

    component utxoNoteLeafHasher_Stage1 = UtxoNoteLeafHasher();
    utxoNoteLeafHasher_Stage1.originNetworkId <== originNetworkId;
    utxoNoteLeafHasher_Stage1.targetNetworkId <== targetNetworkId;
    utxoNoteLeafHasher_Stage1.createTime <== createTime;
    utxoNoteLeafHasher_Stage1.originZoneId <== originZoneId;
    utxoNoteLeafHasher_Stage1.targetZoneId <== targetZoneId;
    utxoNoteLeafHasher_Stage1.zAccountId <== zAccountId;

    component utxoNoteTowStageHasher = UtxoNoteTwoStageHasher();
    utxoNoteTowStageHasher.spendPk[0] <== spendPk[0];
    utxoNoteTowStageHasher.spendPk[1] <== spendPk[1];
    utxoNoteTowStageHasher.zAsset <== zAsset;
    utxoNoteTowStageHasher.amount <== amount;
    utxoNoteTowStageHasher.leaf <== utxoNoteLeafHasher_Stage1.out;

    out <== utxoNoteTowStageHasher.out;
}
