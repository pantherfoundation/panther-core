//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./multiOR.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

// 2 Level hash, first level is private parameters, second level is quasi-private,
// since in generare-deposits api, spendPk, zAsset and amount are publicly know parameters
template UtxoNoteHasher(isHiddenHash){
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

    component hiden_hash = Poseidon(9);
    hiden_hash.inputs[0] <== spendPk[0];
    hiden_hash.inputs[1] <== spendPk[1];
    hiden_hash.inputs[2] <== zAsset;
    hiden_hash.inputs[3] <== zAccountId;
    hiden_hash.inputs[4] <== originNetworkId;
    hiden_hash.inputs[5] <== targetNetworkId;
    hiden_hash.inputs[6] <== createTime;
    hiden_hash.inputs[7] <== originZoneId;
    hiden_hash.inputs[8] <== targetZoneId;

    // quasi-public hash - used for generate-deposits
    component hasher = Poseidon(2);

    hasher.inputs[0] <== amount;
    hasher.inputs[1] <== hiden_hash.out;

    if ( isHiddenHash ) {
        out <== hiden_hash.out;
    }
    else {
        out <== hasher.out;
    }
}
