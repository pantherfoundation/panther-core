//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./merkleInclusionProof.circom";
include "./merkleTreeRootBuilder.circom";

// It computes the new root of a binary Merkle tree, if one of the inner nodes
// (and its child elements down the leafs) gets replaced with a subtree built
// from a batch of new leafs.
template BatchUpdaterAndNewRootBuilder(
    tree_levels,   // depth of the tree being updated
    batch_levels   // depth of the subtree with new leafs
) {
    var upperLevels = tree_levels - batch_levels;
    var nNewLeafs = 2**batch_levels;

    // Leafs to build the subtree that replaces the `replacedNode`
    signal input newLeafs[nNewLeafs];

    // The tree old root that includes the `replacedNode` original value
    signal input root;

    // Original value, path elements and indices of the node to be replaced
    signal input replacedNode;
    signal input replacePathElements[upperLevels];
    signal input replacePathIndices[upperLevels];

    // The tree new root that includes the replaced `replacedNode`
    signal output newRoot;

    assert(tree_levels > batch_levels);

    component upperTree = MerkleInclusionProof(upperLevels);
    component batchTree = MerkleTreeRootBuilder(batch_levels);
    component newUpperTree = MerkleInclusionProof(upperLevels);

    // Verify the Merkle inclusion proof for the replacedNode
    upperTree.leaf <== replacedNode;
    for (var l=0; l<upperLevels; l++) {
        upperTree.pathElements[l] <== replacePathElements[l];
        upperTree.pathIndices[l] <== replacePathIndices[l];
    }
    upperTree.root === root;

    // Compute the subtree root to replace the `replacedNode` with
    for (var i = 0; i < nNewLeafs; i++) {
        batchTree.leafs[i] <== newLeafs[i];
    }

    // Compute the new root when the new value in the `replacedNode`
    newUpperTree.leaf <== batchTree.root;
    for (var l=0; l<upperLevels; l++) {
        newUpperTree.pathElements[l] <== replacePathElements[l];
        newUpperTree.pathIndices[l] <== replacePathIndices[l];
    }
    newRoot <== newUpperTree.root;
}
