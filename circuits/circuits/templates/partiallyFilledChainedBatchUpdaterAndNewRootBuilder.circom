//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./batchUpdaterAndNewRootBuilder.circom";
include "./partiallyFilledChainBuilder.circom";
include "./zeroPaddedInputChecker.circom";

// It computes the new root of a binary Merkle tree, if one of the inner nodes
// (and its child elements down the leafs) gets replaced with a subtree built
// from new leafs (batch). The root of the degenerate binary tree (aka "chain")
// built from these new leafs serves as the commitment to these leafs.
//
template PartiallyFilledChainedBatchUpdaterAndNewRootBuilder(
    tree_levels,   // depth of the tree being updated
    batch_levels,  // depth of the subtree with new leafs
    zeroLeafValue
) {
    var upperLevels = tree_levels - batch_levels;
    var nNewLeafs = 2**batch_levels;

    // Root of the degenerate binary tree built from the new leafs
    signal input newLeafsCommitment;
    // Leafs to build the subtree that replaces the `replacedNode`
    signal input newLeafs[nNewLeafs];
    // Number of non-zero new leafs (MUST be first array elements followed by zero leafs)
    signal input nNonZeroNewLeafs;

    // The tree old root that includes the `replacedNode` original value
    signal input root;

    // Original value, path elements and indices of the node to be replaced
    signal input replacedNode;
    signal input replacePathElements[upperLevels];
    signal input replacePathIndices[upperLevels];

    // The tree new root that includes the replaced `replacedNode`
    signal output newRoot;

    assert(tree_levels > batch_levels);
    assert(nNewLeafs >= nNonZeroNewLeafs);

    component inputChecker = ZeroPaddedInputChecker(nNewLeafs, zeroLeafValue);
    component chain = PartiallyFilledChainBuilder(nNewLeafs);

    inputChecker.nInputs <== nNonZeroNewLeafs;
    chain.nInputs <== nNonZeroNewLeafs;

    for (var i=0; i<nNewLeafs; i++) {
        inputChecker.inputs[i] <== newLeafs[i];
        chain.inputs[i] <== newLeafs[i];
    }
    // Ensure the commitment to new leafs is valid
    newLeafsCommitment === chain.out;

    // Compute the tree new root
    component treeUpdater = BatchUpdaterAndNewRootBuilder(tree_levels, batch_levels);
    treeUpdater.root <== root;
    treeUpdater.replacedNode <== replacedNode;

    for (var l=0; l<upperLevels; l++) {
        treeUpdater.replacePathElements[l] <== replacePathElements[l];
        treeUpdater.replacePathIndices[l] <== replacePathIndices[l];
    }

    for (var i=0; i<nNewLeafs; i++) {
        treeUpdater.newLeafs[i] <== newLeafs[i];
    }

    newRoot <== treeUpdater.newRoot;
}
