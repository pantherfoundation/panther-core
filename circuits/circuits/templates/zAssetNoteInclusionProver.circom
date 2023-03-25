//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth){
    // Poseidon ( 1 - Poseidon(1,2,3), 2 - Poseidon(4,5,6,7) )
    signal input zAsset;      // 64 bit ( was 160 )
    signal input token;       // 160 bit - ERC20 address
    signal input tokenId;     // 256 bit - NFT-ID/Token-ID, can be zero in-case some LSB bits from zAssetID is used for NFT-count
    signal input network;     // 6 bit - network-id where UTXO is spent (UTXO-in)
    signal input offset;      // 6 bit - 0..32 bit number, default value is 0 - means all 64 bit of zAssetID is in use
    signal input weight;      // 32 bit
    signal input scale;       // 7 bit - 10^scale MUST be < 2^252 --> scale must be < 90
    signal input merkleRoot;
    signal input pathIndex[ZAssetMerkleTreeDepth];
    signal input pathElements[ZAssetMerkleTreeDepth];

    assert(zAsset < 2**64);
    assert(network < 2**6);
    assert(offset < 33);
    assert(token < 2**160);
    assert(tokenId < 2**252); // special case since field-element bit range
    assert(weight < 2**32);
    assert(scale < 90);

    component merkleVerifier = MerkleTreeInclusionProofDoubleLeaves(ZAssetMerkleTreeDepth);

    component hash[3];
    hash[0] = Poseidon(3);
    hash[1] = Poseidon(4);
    hash[2] = Poseidon(2);

    // 1
    hash[0].inputs[0] <== zAsset;
    hash[0].inputs[1] <== token;
    hash[0].inputs[2] <== tokenId;
    // 2
    hash[1].inputs[0] <== network;
    hash[1].inputs[1] <== offset;
    hash[1].inputs[2] <== weight;
    hash[1].inputs[3] <== scale;
    // 3 - top hash
    hash[2].inputs[0] <== hash[0].out;
    hash[2].inputs[1] <== hash[1].out;

    merkleVerifier.leaf <== hash[2].out;

    for (var i = 0; i < ZAssetMerkleTreeDepth; i++){
        merkleVerifier.pathIndices[i] <== pathIndex[i];
        merkleVerifier.pathElements[i] <== pathElements[i];
    }

    // verify computed root against provided one
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== merkleVerifier.root;
    isEqual.in[1] <== merkleRoot;
    isEqual.enabled <== merkleRoot;
    // merkleRoot === merkleVerifier.root
}
