//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

/*
Check https://github.com/panther-core/circuits/blob/triad-tree/docs/triadMerkleTree.md.
We use the "triad binary tree", a modified Merkle binary tree with 3 child
nodes on the leaf level (other levels have 2 child nodes).
Path indices represented as bits of the `pathIndices` signal, one per level,
except the leaf level that takes 2 lowest bits. Apart from the leaf level, if
the path index for a level is 0, the path element for that level is the left
node in a pair (if the index is 1, the element is the right one).
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

    // first, hash 3 leaves ...
    hashers[0] = Poseidon(3);

    // enforcing that 2 bits of the leaf level index can't be 11
    0 === pathIndices[0]*pathIndices[1];

    hashers[0].inputs[0] <== leaf + (pathIndices[0]+pathIndices[1])*(pathElements[0] - leaf);
    temp <== pathElements[0] + pathIndices[0]*(leaf - pathElements[0]);
    hashers[0].inputs[1] <== temp + pathIndices[1]*(pathElements[1] - pathElements[0]);
    hashers[0].inputs[2] <== pathElements[1] + pathIndices[1]*(leaf -pathElements[1]);

    // ... then iterate through levels above leaves
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

template MerkleTreeInclusionProofDoubleLeaves(n_levels) {
    signal input leaf;
    signal input pathIndices[n_levels];
    signal input pathElements[n_levels];

    signal output root;

    component hashers[n_levels];
    component switchers[n_levels];

    // first, hash 2 leaves ...
    switchers[0] = Switcher();
    switchers[0].L <== leaf;
    switchers[0].R <== pathElements[0];
    switchers[0].sel <== pathIndices[0];

    hashers[0] = Poseidon(2);
    hashers[0].inputs[0] <== switchers[0].outL;
    hashers[0].inputs[1] <== switchers[0].outR;

    // ... then iterate through levels above leaves
    for (var i = 1; i < n_levels; i++) {
        // (outL,outR) = sel==0 ? (L,R) : (R,L)
        switchers[i] = Switcher();
        switchers[i].L <== hashers[i-1].out;
        switchers[i].R <== pathElements[i];
        switchers[i].sel <== pathIndices[i];
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== switchers[i].outL;
        hashers[i].inputs[1] <== switchers[i].outR;
    }

    root <== hashers[n_levels-1].out;
}

