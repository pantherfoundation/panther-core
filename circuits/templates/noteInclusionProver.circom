//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";


/*
Check https://github.com/pantherprotocol/panther-protocol/blob/triad-tree/docs/triadMerkleTree.md.
We use the "triad binary tree", a modified Merkle binary tree with 3 child
nodes on the leaf level (other levels have 2 child nodes).
Path indices represented as bits of the `pathIndices` signal, one per level,
except the leaf level that takes 2 bits. Apart from the leaf level, if the
path index for a level is 0, the path element for that level is the left node
in a pair (if the index is 1, the element is the right one).
The `pathElements` array of signals sets path elements. The first 2 elements
in the array are leaves (pair leaves to the one set by the `leaf` signal).
*/

template MerkleTreeInclusionProof(n_levels) {
    signal input leaf;
    signal input pathIndices[n_levels+1];
    signal input pathElements[n_levels+1]; // extra slot for third leave

    signal output root;

    component hashers[n_levels];
    component switchers[n_levels-1];
    signal temp;

    hashers[0] = Poseidon(3);

    // enforece that bh,bl can't be 11
    0 === pathIndices[0]*pathIndices[1];
    hashers[0].inputs[0] <== leaf + (pathIndices[0]+pathIndices[1])*(pathElements[0] - leaf);
    temp <== pathElements[0] + pathIndices[0]*(leaf - pathElements[0]);
    hashers[0].inputs[1] <== temp + pathIndices[1]*(pathElements[1] - pathElements[0]);
    hashers[0].inputs[2] <== pathElements[1] + pathIndices[1]*(leaf -pathElements[1]);

    for (var i = 1; i < n_levels; i++) {
        // (outL,outR) = sel==0 ? (L,R) : (R,L)
        switchers[i-1] = Switcher();
        switchers[i-1].L <== hashers[i-1].out;
        switchers[i-1].R <== pathElements[i+1];
        switchers[i-1].sel <== pathIndices[i+1];
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== switchers[i-1].outL;
        hashers[i].inputs[1] <== switchers[i-1].outR;
    }

    root <== hashers[n_levels-1].out;
}

template NoteInclusionProver(n_levels) {
    signal input root;
    signal input note;
    signal input pathIndices[n_levels+1];
    signal input pathElements[n_levels+1]; // extra slot for third leave
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
