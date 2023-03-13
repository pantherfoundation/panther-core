//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth){
    signal input zAsset; // 160 bit
    signal input weight; // 32 bit
    signal input merkleRoot;
    signal input pathIndex[ZAssetMerkleTreeDepth];
    signal input pathElements[ZAssetMerkleTreeDepth];

    component merkleVerifier = MerkleTreeInclusionProofDoubleLeaves(ZAssetMerkleTreeDepth);

    component b2n = Bits2Num(160 + 32);

    component n2bToken = Num2Bits(160);
    n2bToken.in <== zAsset;

    for (var i = 192; i > 32; i--) {
        b2n.in[i-1] <== n2bToken.out[i-32-1];
    }

    component n2bWeight = Num2Bits(32);
    n2bWeight.in <== weight;

    for (var i = 32; i > 0; i--) {
        b2n.in[i-1] <== n2bToken.out[i];
    }

    merkleVerifier.leaf <== b2n.out;

    for (var i = 0; i < ZAssetMerkleTreeDepth; i++){
        merkleVerifier.pathIndices[i] <== pathIndex[i];
        merkleVerifier.pathElements[i] <== pathElements[i];
    }
    merkleVerifier.root === merkleRoot;
}
