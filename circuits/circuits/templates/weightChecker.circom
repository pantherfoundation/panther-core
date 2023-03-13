//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./noteInclusionProver.circom";
include "./weightLeafDecoder.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template WeightChecker(WeightMerkleTreeDepth){
    signal input leaf;
    signal input token;
    signal input merkleRoot;
    signal input pathElements[WeightMerkleTreeDepth+1];
    signal output weight;

    component merkleVerifier = MerkleTreeInclusionProof(WeightMerkleTreeDepth);
    component weightDecoder = WeightLeafDecoder(WeightMerkleTreeDepth);

    weightDecoder.leaf <== leaf;
    weight <== weightDecoder.weight;

    // assert that weightToken = 0 or weightToken = token
    0 === (weightDecoder.token-token)*weightDecoder.token;

    merkleVerifier.leaf <== leaf;
    for (var i=0; i<WeightMerkleTreeDepth+1; i++){
        merkleVerifier.pathIndices[i] <== weightDecoder.index[i];
        merkleVerifier.pathElements[i] <== pathElements[i];
    }
    merkleVerifier.root === merkleRoot;
}
