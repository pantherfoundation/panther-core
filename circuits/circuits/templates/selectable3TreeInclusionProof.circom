//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./merkleInclusionProof.circom";
include "./selector3.circom";

// Based upon the given leaf, path elements and indices, compute the root
// of the merkle tree chosen from 3 trees by the `treeSelector` signal.
//
template Selectable3TreeInclusionProof(
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
    // Enforce treeSelector is 0|1
    for(var i = 0; i < 2; i++) {
        treeSelector[i] - treeSelector[i] * treeSelector[i] === 0;
    }

    // Assuming the leaf is in the left tree, compute the left tree root
    component lTree = MerkleInclusionProof(l_levels);
    lTree.leaf <== leaf;
    for (var l=0; l<l_levels; l++) {
        // elements which follow the first `l_levels` ones, are ignored
        lTree.pathElements[l] <== pathElements[l];
        lTree.pathIndices[l] <== pathIndices[l];
        // Enforce path-index is binary
        pathIndices[l] - pathIndices[l] * pathIndices[l] === 0;
    }

    // Assuming the leaf is in the middle tree, go on computing the root
    component mTree = MerkleInclusionProof(m_extraLevels);
    mTree.leaf <== lTree.root;
    for (var l=0; l<m_extraLevels; l++) {
        mTree.pathElements[l] <== pathElements[l_levels+l];
        mTree.pathIndices[l] <== pathIndices[l_levels+l];
    }

    // Assuming the leaf is in the right tree, go on computing the root
    component rTree = MerkleInclusionProof(r_extraLevels);
    rTree.leaf <== mTree.root;
    for (var l=0; l<r_extraLevels; l++) {
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
