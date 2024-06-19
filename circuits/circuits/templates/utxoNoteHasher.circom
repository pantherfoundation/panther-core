//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

// 2 Level hash, first level is private parameters, second level is quasi-private,
// since in generare-deposits api, spendPk, zAsset and amount are publicly know parameters
template UtxoNoteHasher(isHiddenHash){
    signal input {sub_order_bj_p} spendPk[2];            // 256
    signal input {uint64}         zAsset;                // 64
    signal input {uint64}         amount;                // 64
    signal input {uint6}          originNetworkId;       // 6
    signal input {uint6}          targetNetworkId;       // 6
    signal input {uint32}         createTime;            // 32
    signal input {uint16}         originZoneId;          // 16
    signal input {uint16}         targetZoneId;          // 16
    signal input {uint24}         zAccountId;            // 24
    signal input {sub_order_bj_p} dataEscrowPubKey[2];   // 256

    signal output out;

    // 2 x 6-bit-networkId | 32-bit-createTime | 16-bit-origin-zone-id | 16-bit-target-zone-id
    assert(originNetworkId < 2**6);
    assert(targetNetworkId < 2**6);
    assert(createTime < 2**32);
    assert(originZoneId < 2**16);
    assert(targetZoneId < 2**16);
    assert(zAccountId < 2**24);

    component hiden_hash = Poseidon(11);
    hiden_hash.inputs[0] <== spendPk[0];
    hiden_hash.inputs[1] <== spendPk[1];
    hiden_hash.inputs[2] <== zAsset;
    hiden_hash.inputs[3] <== zAccountId;
    hiden_hash.inputs[4] <== originNetworkId;
    hiden_hash.inputs[5] <== targetNetworkId;
    hiden_hash.inputs[6] <== createTime;
    hiden_hash.inputs[7] <== originZoneId;
    hiden_hash.inputs[8] <== targetZoneId;
    hiden_hash.inputs[9] <== dataEscrowPubKey[0];
    hiden_hash.inputs[10] <== dataEscrowPubKey[1];

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
