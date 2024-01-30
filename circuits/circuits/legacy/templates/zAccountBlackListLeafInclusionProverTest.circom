//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../templates/zAccountNoteInclusionProver.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";
include "../../../node_modules/circomlib/circuits/comparators.circom";
include "../../../node_modules/circomlib/circuits/gates.circom";

template ZAccountBlackListLeafInclusionProverTest(ZAccountBlackListMerkleTreeDepth){
    signal input zAccountId;
    signal input leaf;
    signal input merkleRoot;
    signal input pathElements[ZAccountBlackListMerkleTreeDepth];

    component zAccountBlackListInlcusionProver = ZAccountNoteInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.note <== leaf;
    zAccountBlackListInlcusionProver.root <== merkleRoot;

    assert(ZAccountBlackListMerkleTreeDepth < 17);
    assert(zAccountId < 2**(ZAccountBlackListMerkleTreeDepth+8));

    // copy path ellements
    for (var j = 0; j < ZAccountBlackListMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== pathElements[j];
    }

    component n2b_zAccountId = Num2Bits(ZAccountBlackListMerkleTreeDepth+8); // LSB is a bit number inside leaf
    n2b_zAccountId.in <== zAccountId;

    // build the path inside merkle-tree
    for (var j = 0; j < ZAccountBlackListMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathIndices[j] <== n2b_zAccountId.out[j+8]; // +8 --> path is ZAccountBlackListMerkleTreeDepth MSB bits
    }

    // build the index inside leaf
    component b2n_zAccountIdInsideLeaf = Bits2Num(8);
    for (var j = 0; j < 8; j++) {
        b2n_zAccountIdInsideLeaf.in[j] <== n2b_zAccountId.out[j];
    }

    assert(b2n_zAccountIdInsideLeaf.out < 254); // regular scalar field size

    signal temp;
    temp <-- 1 << b2n_zAccountIdInsideLeaf.out; // switch-on single bit

    component and = AND(); // check that this bit it 1
    and.a <== leaf;
    and.b <== temp;

    component isZero = IsZero(); // require to be zero
    isZero.in <== and.out;

    isZero.out === 1;
}
