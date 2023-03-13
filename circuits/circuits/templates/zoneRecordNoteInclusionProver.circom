//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

template ZoneRecordNoteInclusionProver(n_levels) {
    signal input root;
    signal input zoneRecordCommitment;
    signal input pathIndices[n_levels];
    signal input pathElements[n_levels];

    // compute the root from the Merkle inclusion proof
    component proof = MerkleTreeInclusionProofDoubleLeaves(n_levels);
    proof.leaf <== zoneRecordCommitment;
    for (var i = 0; i < n_levels; i++){
        proof.pathIndices[i] <== pathIndices[i];
        proof.pathElements[i] <== pathElements[i];
    }
    // verify computed root against provided one if UTXO is non-zero
    root === proof.root;
}
