//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth){
    signal input {uint64}           zAsset;      // 64 bit ( was 160 )
    signal input {uint168}          token;       // 160 bit - ERC20 address
    signal input {uint252}          tokenId;     // 256 bit - NFT-ID/Token-ID, can be zero in-case some LSB bits from zAssetID is used for NFT-count
    signal input {uint6}            network;     // 6 bit - network-id where UTXO is spent (UTXO-in)
    signal input {uint6}            offset;      // 6 bit - 0..32 bit number, default value is 0 - means all 64 bit of zAssetID is in use
    signal input {non_zero_uint32}  weight;      // 32 bit
    signal input {non_zero_uint64}  scale;       // 64 bit
    signal input                    merkleRoot;
    signal input {binary}           pathIndices[ZAssetMerkleTreeDepth];
    signal input                    pathElements[ZAssetMerkleTreeDepth];

    assert(zAsset < 2**64);
    assert(network < 2**6);
    assert(offset < 33);
    assert(token < 2**160);
    assert(tokenId < 2**252); // special case since field-element bit range
    assert(weight < 2**32);

    component merkleVerifier = MerkleTreeInclusionProofDoubleLeaves(ZAssetMerkleTreeDepth);

    component hash = Poseidon(7);
    hash.inputs[0] <== zAsset;
    hash.inputs[1] <== token;
    hash.inputs[2] <== tokenId;
    hash.inputs[3] <== network;
    hash.inputs[4] <== offset;
    hash.inputs[5] <== weight;
    hash.inputs[6] <== scale;

    merkleVerifier.leaf <== hash.out;

    for (var i = 0; i < ZAssetMerkleTreeDepth; i++){
        merkleVerifier.pathIndices[i] <== pathIndices[i];
        merkleVerifier.pathElements[i] <== pathElements[i];
    }

    // verify computed root against provided one
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== merkleVerifier.root;
    isEqual.in[1] <== merkleRoot;
    isEqual.enabled <== merkleRoot;
    // merkleRoot === merkleVerifier.root
}
