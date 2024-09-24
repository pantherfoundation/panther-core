//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./zAccountNoteInclusionProver.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

/*
This template checks if the ZAccount is blacklisted or not.

@input signals:
1. zAccountId - unique zAccountId for a ZAccount
2. leaf - commitment
3. merkleRoot - merkle root of the ZAccount Blacklist merkle tree
4. pathElements - path elements that leads to the merkle root
*/
template ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth){
    signal input {uint24} zAccountId;
    signal input          leaf;
    signal input          merkleRoot;
    signal input          pathElements[ZAccountBlackListMerkleTreeDepth];

    component zAccountBlackListInlcusionProver = ZAccountNoteInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.note <== leaf;
    zAccountBlackListInlcusionProver.root <== merkleRoot;

    assert(ZAccountBlackListMerkleTreeDepth < 17);
    assert(zAccountId < 2**(ZAccountBlackListMerkleTreeDepth+8));

    // copy path elements
    for (var j = 0; j < ZAccountBlackListMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== pathElements[j];
    }

    component n2b_zAccountId = Num2Bits(ZAccountBlackListMerkleTreeDepth+8); // LSB is a bit number inside leaf
    n2b_zAccountId.in <== zAccountId;

    var ACTIVE = Active();
    // build the path inside merkle-tree
    for (var j = 0; j < ZAccountBlackListMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathIndices[j] <== BinaryTag(ACTIVE)(n2b_zAccountId.out[j+8]); // +8 --> path is ZAccountBlackListMerkleTreeDepth MSB bits
    }

    // build the index inside leaf
    component b2n_zAccountIdInsideLeaf = Bits2Num(8);
    for (var j = 0; j < 8; j++) {
        b2n_zAccountIdInsideLeaf.in[j] <== n2b_zAccountId.out[j];
    }

    assert(b2n_zAccountIdInsideLeaf.out < 254); // regular scalar field size

    // switch-on single bit
    component n2b_leaf = Num2Bits(254);
    n2b_leaf.in <== leaf;

    component is_zero[254];

    for(var i = 0; i < 254; i++) {
        // is_zero[i].out == 1 only when i == b2n_zAccountIdInsideLeaf.out
        is_zero[i] = IsZero();
        is_zero[i].in <== i - b2n_zAccountIdInsideLeaf.out;
        // make sure that for our zAccountId LSB inside leaf, the bit is zero,
        // for example: zAccountId LSB = 200, for i = 200, is_zero[i].out == 1 --> if n2b_leaf.out[i] == 1, then the assertion will fail
        // which means that our zAccountId is blacklisted !
        is_zero[i].out * n2b_leaf.out[i] === 0;
    }
}
