//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./merkleInclusionProof.circom";
include "./merkleTreeBuilder.circom";

// It computes the new root of a binary Merkle tree, if one of the inner nodes
// (and all its child elements) gets replaced with the root of the subtree built
// from a batch of new leafs.
template TreeFullBatchUpdaterAndNewRootBuilder(
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
    signal input replacedNodePathElements[upperLevels];
    signal input replacedNodePathIndices[upperLevels];

    // The tree new root that includes the replaced `replacedNode`
    signal output newRoot;

    assert(tree_levels > batch_levels);

    component upperTree = MerkleInclusionProof(upperLevels);
    component batchTree = MerkleTreeBuilder(batch_levels);
    component newUpperTree = MerkleInclusionProof(upperLevels);

    // Verify the Merkle inclusion proof for the replacedNode
    upperTree.leaf <== replacedNode;
    for (var l=0; l<upperLevels; l++) {
        upperTree.pathElements[l] <== replacedNodePathElements[l];
        upperTree.pathIndices[l] <== replacedNodePathIndices[l];
    }
    upperTree.root === root;

    // Compute the subtree root to replace the `replacedNode` with
    for (var i = 0; i < nNewLeafs; i++) {
        batchTree.leafs[i] <== newLeafs[i];
    }

    // Compute the new root for the new value in the `replacedNode`
    newUpperTree.leaf <== batchTree.root;
    for (var l=0; l<upperLevels; l++) {
        newUpperTree.pathElements[l] <== replacedNodePathElements[l];
        newUpperTree.pathIndices[l] <== replacedNodePathIndices[l];
    }
    newRoot <== newUpperTree.root;
}
