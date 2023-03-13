//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./zAccountNoteInclusionProver.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth){
    signal input zAccountId;
    signal input leaf;
    signal input merkleRoot;
    signal input pathElements[ZAccountBlackListMerkleTreeDepth];

    component zAccountBlackListInlcusionProver = ZAccountNoteInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.note <== leaf;
    zAccountBlackListInlcusionProver.root <== merkleRoot;

    assert(ZAccountBlackListMerkleTreeDepth < 17);
    assert(zAccountId < 2**(ZAccountBlackListMerkleTreeDepth+8));

    component n2b_zAccountId = Num2Bits(ZAccountBlackListMerkleTreeDepth+8); // LSB is number of bit inside leaf
    n2b_zAccountId.in <== zAccountId;
    for (var j = 0; j < ZAccountBlackListMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== pathElements[j];
    }
    for (var j = ZAccountBlackListMerkleTreeDepth; j > 0; j--) {
        zAccountBlackListInlcusionProver.pathIndices[j-1] <== n2b_zAccountId.out[j+8-1]; // +8 --> path is MSB
    }

    component b2n_zAccountIdInsideLeaf = Bits2Num(8);
    for (var j = 0; j < 8; j++) {
        b2n_zAccountIdInsideLeaf.in[j] <== n2b_zAccountId.out[j];
    }
    assert(b2n_zAccountIdInsideLeaf.out < 253); // regular BabyJubJub limit

    signal temp;
    temp <-- 1 << b2n_zAccountIdInsideLeaf.out; // switch-on single bit

    component and = AND(); // check that this bit it 1
    and.a <== leaf;
    and.b <== temp;

    component isZero = IsZero(); // require
    isZero.in <== and.out;

    isZero.out === 0;
}
