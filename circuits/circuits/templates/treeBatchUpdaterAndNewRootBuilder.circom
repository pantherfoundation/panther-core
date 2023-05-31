//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./batchUpdaterAndNewRootBuilder.circom";
include "./partiallyFilledChainBuilder.circom";
include "./zeroPaddedInputChecker.circom";

// It computes the new root of a binary Merkle tree, if one of the inner nodes
// (and all its child elements) gets replaced with a root of the subtree built
// from a batch of new leafs. The root of the degenerate binary tree ("chain")
// built from these new leafs serves as the commitment to these leafs.
//
template TreeBatchUpdaterAndNewRootBuilder(
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

    // Original value, index, and path elements of the node to be replaced
    signal input replacedNode;
    signal input replacedNodeIndex;
    signal input replacedNodePathElements[upperLevels];

    // Other public input to anchor into the proof
    signal input extraInput;

    // The tree new root that includes the replaced `replacedNode`
    signal output newRoot;

    assert(tree_levels > batch_levels);
    assert(nNewLeafs >= nNonZeroNewLeafs);
    assert(replacedNodeIndex < 2**upperLevels);

    component inputChecker = ZeroPaddedInputChecker(nNewLeafs, zeroLeafValue);
    component chain = PartiallyFilledChainBuilder(nNewLeafs);

    inputChecker.nInputs <== nNonZeroNewLeafs;
    chain.nInputs <== nNonZeroNewLeafs;

    // Compute pathIndices (for pathElements) of the node to be replaced
    signal replacedNodePathIndices[upperLevels];
    component indexBityfier = Num2Bits(upperLevels);

    indexBityfier.in <== replacedNodeIndex;
    for (var l = 0; l < upperLevels; l++) {
        replacedNodePathIndices[l] <== indexBityfier.out[l];
    }

    for (var i=0; i<nNewLeafs; i++) {
        inputChecker.inputs[i] <== newLeafs[i];
        chain.inputs[i] <== newLeafs[i];
    }
    // Ensure the commitment to new leafs is valid
    newLeafsCommitment === chain.out;

    // Compute the tree new root
    component treeUpdater = TreeFullBatchUpdaterAndNewRootBuilder(tree_levels, batch_levels);
    treeUpdater.root <== root;
    treeUpdater.replacedNode <== replacedNode;

    for (var l=0; l<upperLevels; l++) {
        treeUpdater.replacedNodePathElements[l] <== replacedNodePathElements[l];
        treeUpdater.replacedNodePathIndices[l] <== replacedNodePathIndices[l];
    }

    for (var i=0; i<nNewLeafs; i++) {
        treeUpdater.newLeafs[i] <== newLeafs[i];
    }

    newRoot <== treeUpdater.newRoot;

    // Ensure extraInput can't be cheated
    extraInput === extraInput * 1;
}
