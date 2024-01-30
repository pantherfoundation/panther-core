//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../templates/merkleTreeInclusionProof.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";
include "../../../node_modules/circomlib/circuits/comparators.circom";
include "../../../node_modules/circomlib/circuits/poseidon.circom";
include "../../../node_modules/circomlib/circuits/switcher.circom";

template NoteInclusionProver(n_levels) {
    signal input root;
    signal input note;
    signal input pathIndices[n_levels+1];
    signal input pathElements[n_levels+1]; // extra slot for 3rd leave
    signal input utxoAmount;

    // compute the root from the Merkle inclusion proof
    component proof = MerkleTreeInclusionProof(n_levels);
    proof.leaf <== note;
    for (var i=0; i<n_levels+1; i++){
        proof.pathIndices[i] <== pathIndices[i];
        proof.pathElements[i] <== pathElements[i];
    }

    // check if UTXO amount is zero
    component isZeroUtxo = IsZero();
    isZeroUtxo.in <== utxoAmount;

    // verify computed root against provided one if UTXO is non-zero
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== root;
    isEqual.in[1] <== proof.root;
    isEqual.enabled <== 1-isZeroUtxo.out;
}
