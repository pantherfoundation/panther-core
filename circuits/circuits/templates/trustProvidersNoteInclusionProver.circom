//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

template TrustProvidersNoteInclusionProver(n_levels) {
    signal input                    enabled;
    signal input                    root;
    signal input {sub_order_bj_p}   key[2];
    signal input {uint32}           expiryTime;
    signal input {binary}           pathIndices[n_levels];
    signal input                    pathElements[n_levels];

    assert(enabled < 2);
    enabled * enabled - enabled === 0;

    // verify expiryTime
    component expiryTimeIsZero = IsZero();
    expiryTimeIsZero.in <== expiryTime;
    // out = 1 if expiryTime is equal to 0
    // out = 0 if expiryTime is NOT equal to 0
    // if enabled = 1 -> require expiryTime != 0
    // if enabled = 0 -> require expiryTime == 0
    expiryTimeIsZero.out === (1-enabled);

    // compute hash
    component hash = Poseidon(3);
    hash.inputs[0] <== key[0];
    hash.inputs[1] <== key[1];
    hash.inputs[2] <== expiryTime;

    // compute the root from the Merkle inclusion proof
    component proof = MerkleTreeInclusionProofDoubleLeaves(n_levels);
    proof.leaf <== hash.out;
    for (var i = 0; i < n_levels; i++){
        proof.pathIndices[i] <== pathIndices[i];
        proof.pathElements[i] <== pathElements[i];
    }
    // verify computed root against provided one
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== root;
    isEqual.in[1] <== proof.root;
    isEqual.enabled <== enabled;
}
