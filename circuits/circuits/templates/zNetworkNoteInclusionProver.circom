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
    signal input pathIndex[ZNetworkMerkleTreeDepth];
    signal input pathElements[ZNetworkMerkleTreeDepth];

    component merkleVerifier = MerkleTreeInclusionProofDoubleLeaves(ZNetworkMerkleTreeDepth);

    component hash = Poseidon(8);
    hash.inputs[0] <== active;
    hash.inputs[1] <== chainId;
    hash.inputs[2] <== networkId;
    hash.inputs[3] <== forTxReward;
    hash.inputs[4] <== forUtxoReward;
    hash.inputs[5] <== forDepositReward;
    hash.inputs[6] <== daoDataEscrowPubKey[0];
    hash.inputs[7] <== daoDataEscrowPubKey[1];

    merkleVerifier.leaf <== hash.out;

    for (var i = 0; i < ZNetworkMerkleTreeDepth; i++){
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
