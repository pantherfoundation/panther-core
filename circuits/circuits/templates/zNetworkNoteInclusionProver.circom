//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template ZNetworkNoteInclusionProver(ZNetworkMerkleTreeDepth){
    // Poseidon ( ... )
    signal input active;                  // 1 bit
    signal input networkId;               // 6 bit
    signal input chainId;                 // 256 bit
    signal input networkIDsBitMap;        // 64 bit
    signal input forTxReward;             // 40 bit
    signal input forUtxoReward;           // 40 bit
    signal input forDepositReward;        // 40 bit
    signal input daoDataEscrowPubKey[2];  // 2 x 256 bit
    signal input merkleRoot;
    signal input pathIndices[ZNetworkMerkleTreeDepth];
    signal input pathElements[ZNetworkMerkleTreeDepth];

    component merkleVerifier = MerkleTreeInclusionProofDoubleLeaves(ZNetworkMerkleTreeDepth);

    component hash = Poseidon(9);
    hash.inputs[0] <== active;
    hash.inputs[1] <== chainId;
    hash.inputs[2] <== networkId;
    hash.inputs[3] <== networkIDsBitMap;
    hash.inputs[4] <== forTxReward;
    hash.inputs[5] <== forUtxoReward;
    hash.inputs[6] <== forDepositReward;
    hash.inputs[7] <== daoDataEscrowPubKey[0];
    hash.inputs[8] <== daoDataEscrowPubKey[1];


    merkleVerifier.leaf <== hash.out;

    for (var i = 0; i < ZNetworkMerkleTreeDepth; i++){
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
