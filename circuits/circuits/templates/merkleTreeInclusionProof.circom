//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

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

// Switches one of 3 inputs to the output based upon the `sel` signal.
template Selector3() {
    // Three input signals
    signal input L;
    signal input M;
    signal input R;

    // Selector that chooses the input signal
    signal input sel[2];

    signal output out;

    // Assert sel[i] is 0|1
    assert(sel[0]<=1);
    assert(sel[1]<=1);
    // Enforce sel can't be [1,1]
    0 === sel[0]*sel[1];

    // Considering limitations on `sel` above:
    // | sel[0],sel[1] | inv01 | L*inv01+M*sel[0]+R*sel[1] | Out |
    // |---------------|-------|---------------------------|-----|
    // | 0     ,0      | 1     | L*1    +M*0     +R*0      | L   |
    // | 1     ,0      | 0     | L*0    +M*1     +R*0      | M   |
    // | 0     ,1      | 0     | L*0    +M*0     +R*1      | R   |

    // Intermediary signals
    signal inv0 <== 1-sel[0];
    signal inv1 <== 1-sel[1];
    signal inv01 <== inv0*inv1;
    signal outL <== L*inv01;
    signal outM <== M*sel[0];
    signal outR <== R*sel[1];

    out <== outL + outM + outR;
}

// Based upon the given leaf, path elements and indices, compute the root
// of the merkle tree chosen from 3 trees by the `treeSelector` signal.
//
template MerkleTreeInclusionProofDoubleLeavesSelectable(
    l_levels,       // number of levels bellow the root (depth) of the "left" tree
    m_extraLevels,  // "middle" tree has the depth of `l_levels + m_extraLevels`
    r_extraLevels   // "right" tree depth is `l_levels + m_extraLevels + r_extraLevels`
) {
    // the middle tree must have no less levels than the left one
    var m_levels = l_levels + m_extraLevels;
    // the right tree must have no less levels than the middle one
    var r_levels = m_levels + r_extraLevels;

    // If the left ([0,0]) or middle ([1,0]) or right ([0,1]) tree to be selected
    signal input treeSelector[2];

    signal input leaf;
    signal input pathElements[r_levels];
    signal input pathIndices[r_levels];

    signal output root;

    assert(l_levels > 1);

    // Assert treeSelector[i] is 0|1
    assert(treeSelector[0]<=1);
    assert(treeSelector[1]<=1);
    // Enforce treeSelector can't be [1,1]
    0 === treeSelector[0]*treeSelector[1];

    // Assuming the leaf is in the left tree, compute the left tree root
    component lTree = MerkleTreeInclusionProofDoubleLeaves(l_levels);
    lTree.leaf <== leaf;
    for (var l = 0; l < l_levels; l++) {
        // elements which follow the first `l_levels` ones, are ignored
        lTree.pathElements[l] <== pathElements[l];
        lTree.pathIndices[l] <== pathIndices[l];
    }

    // Assuming the leaf is in the middle tree, go on computing the root
    component mTree = MerkleTreeInclusionProofDoubleLeaves(m_extraLevels);
    mTree.leaf <== lTree.root;
    for (var l = 0; l < m_extraLevels; l++) {
        mTree.pathElements[l] <== pathElements[l_levels+l];
        mTree.pathIndices[l] <== pathIndices[l_levels+l];
    }

    // Assuming the leaf is in the right tree, go on computing the root
    component rTree = MerkleTreeInclusionProofDoubleLeaves(r_extraLevels);
    rTree.leaf <== mTree.root;
    for (var l = 0; l < r_extraLevels; l++) {
        rTree.pathElements[l] <== pathElements[m_levels+l];
        rTree.pathIndices[l] <== pathIndices[m_levels+l];
    }

    // Choose the root to return, based upon `treeSelector`
    component switch = Selector3();
    switch.sel[0] <== treeSelector[0];
    switch.sel[1] <== treeSelector[1];
    switch.L <== lTree.root;
    switch.M <== mTree.root;
    switch.R <== rTree.root;

    root <== switch.out;
}
