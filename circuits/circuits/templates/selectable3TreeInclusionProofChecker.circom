pragma circom 2.1.6;

include "./selectable3TreeInclusionProof.circom";

// Based upon the given leaf, path elements and indices, compute the root
// of the merkle tree chosen from 3 trees by the `treeSelector` signal.
//
template Selectable3TreeInclusionProofChecker(
    l_levels,       // number of levels bellow the root (depth) of the "left" tree
    m_extraLevels,  // "middle" tree has the depth of `l_levels + m_extraLevels`
    r_extraLevels   // "right" tree depth is `l_levels + m_extraLevels + r_extraLevels`
) {
    // the middle tree must have no less levels than the left one
    var m_levels = l_levels + m_extraLevels;
    // the right tree must have no less levels than the middle one
    var r_levels = m_levels + r_extraLevels;

    signal input treeSelector[2];
    signal input leaf;
    signal input pathElements[r_levels];
    signal input pathIndices[r_levels];
    signal input root;

    component proof = Selectable3TreeInclusionProof(l_levels, m_extraLevels, r_extraLevels);

    proof.treeSelector[0] <== treeSelector[0];
    proof.treeSelector[1] <== treeSelector[1];
    proof.leaf <== leaf;
    for (var i=0; i<r_levels; i++) {
        proof.pathElements[i] <== pathElements[i];
        proof.pathIndices[i] <== pathIndices[i];
    }

    root === proof.root;
}
