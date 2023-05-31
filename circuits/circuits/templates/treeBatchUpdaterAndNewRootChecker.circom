//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./treeBatchUpdaterAndNewRootBuilder.circom";

// It verifies the new root of a binary Merkle tree, if one of the inner nodes
// (and its child elements down the leafs) gets replaced with a subtree built
// from new leafs (batch). The root of the degenerate binary tree (aka "chain")
// built from these new leafs serves as the commitment to these leafs.
//
template TreeBatchUpdaterAndNewRootChecker(
    tree_levels,   // depth of the tree being updated
    batch_levels,  // depth of the subtree with new leafs
    zeroLeafValue
) {
    var upperLevels = tree_levels - batch_levels;
    var nNewLeafs = 2**batch_levels;

    // Root of the degenerate binary tree built from the new leafs
    signal input newLeafsCommitment;
    // Leafs to build the subtree that replaces the `nodeBeingReplaced`
    signal input newLeafs[nNewLeafs];
    // Number of non-zero new leafs (MUST be first array elements followed by zero leafs)
    signal input nNonZeroNewLeafs;

    // The tree old root that includes the `nodeBeingReplaced` original value
    signal input root;

    // Original value, index, and path elements of the node to be replaced
    signal input replacedNode;
    signal input replacedNodeIndex;
    signal input replacedNodePathElements[upperLevels];

    // Other public input to anchor into the proof
    signal input extraInput;

    // The tree new root that includes the replaced `replacedNode`
    signal input newRoot;

    component builder = TreeBatchUpdaterAndNewRootBuilder(
        tree_levels,
        batch_levels,
        zeroLeafValue
    );

    builder.newLeafsCommitment <== newLeafsCommitment;
    builder.nNonZeroNewLeafs <== nNonZeroNewLeafs;
    builder.root <== root;
    builder.replacedNode <== replacedNode;
    builder.replacedNodeIndex <== replacedNodeIndex;
    builder.extraInput <== extraInput;

    for (var i=0; i<nNewLeafs; i++) {
         builder.newLeafs[i] <== newLeafs[i];
    }

    for (var l=0; l<upperLevels; l++) {
        builder.replacedNodePathElements[l] <== replacedNodePathElements[l];
    }

    newRoot === builder.newRoot;
}
