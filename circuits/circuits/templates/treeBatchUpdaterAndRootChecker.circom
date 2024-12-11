//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./merkleTreeBuilder.circom";
include "./merkleTreeUpdater.circom";
include "./partiallyFilledChainBuilder.circom";
include "./zeroPaddedInputChecker.circom";
include "./utils.circom";

// It verifies the root of a (fully balanced) binary Merkle tree (the "Tree")
// after insertion of new leafs.
// The branch from these new leafs (the "Batch") replaces the Tree's leftmost
// "empty" subtree of the same height the Batch has. So, the insertion updates
// the value in an inner node (the "replaced node") with the Batch root.
// If the Batch contains "empty" leafs they MUST be the rightmost leafs.
// The root of a degenerate binary Merkle tree, built from the Batch leafs but
// with empty leafs removed, is used as the commitment to the new leafs.
// It also verifies the root of a Tree's bigger branch (the "Branch"), which the
// Batch is a part of.
//
template TreeBatchUpdaterAndRootChecker(
    tree_levels,   // depth of the Tree
    branch_levels, // depth of the Branch
    batch_levels,  // depth of the Batch
    emptyLeaf,     // value in an "empty" leaf
    emptyBatch     // root of an "empty" subtree
) {
    //        *  <----- Tree ----------------+   -------------
    //      /  \                             |
    //     *    *  <--- Branch Subtrees --+  |    upper levels
    //    /\    /\                        |  |
    //   *  *  *  *  <- Batch Subtrees-+  |  |   -------------
    //  / \/ \/ \/ \                   |  |  |    batch levels
    // *** leafs ****  <---------------+--+--+   -------------
    assert(tree_levels > branch_levels);
    assert(branch_levels > batch_levels);
    var upperLevels = tree_levels - batch_levels;
    var nNewLeafs = 2**batch_levels;


    // Root of the Tree before insertion
    signal input oldRoot;

    // Root of the Tree after insertion
    signal input newRoot;

    // Index of the replaced node (0 for the leftmost node)
    signal input replacedNodeIndex;
    // Path elements (sibling nodes) of the replaced node
    signal input pathElements[upperLevels];

    // Commitment to new leafs
    signal input newLeafsCommitment;
    // Number of non-empty new leafs
    signal input nNonEmptyNewLeafs;
    // New leafs (empty leafs, if present, MUST be last elements)
    signal input newLeafs[nNewLeafs];

    // Root of the Batch
    signal input batchRoot;
    // Root of the Branch (after insertion)
    signal input branchRoot;

    // Arbitrary data to anchor into the SNARK-proof
    signal input extraInput;

    // Any value except 0 (groth16 vulnerability work-around)
    signal input magicalConstraint;


    // If the batch has empty leafs, enforce they are last (rightmost) elements
    component inputChecker = ZeroPaddedInputChecker(nNewLeafs, emptyLeaf);
    inputChecker.nInputs <== nNonEmptyNewLeafs;
    for (var i=0; i<nNewLeafs; i++) {
        inputChecker.inputs[i] <== newLeafs[i];
    }

    // Ensure the commitment to new leafs is valid
    component chain = PartiallyFilledChainBuilder(nNewLeafs);
    chain.nInputs <== nNonEmptyNewLeafs;
    for (var i=0; i<nNewLeafs; i++) {
        chain.inputs[i] <== newLeafs[i];
    }
    newLeafsCommitment === chain.out;

    // Compute the root of the Batch
    component batch = MerkleTreeBuilder(batch_levels);
    for (var i = 0; i < nNewLeafs; i++) {
        batch.leafs[i] <== newLeafs[i];
    }

    // Compute pathIndices of the replaced node
    signal {binary} pathIndices[upperLevels];
    component indexBityfier = Num2Bits(upperLevels);
    indexBityfier.in <== replacedNodeIndex;
    for (var l = 0; l < upperLevels; l++) {
        pathIndices[l] <== indexBityfier.out[l];
    }

    // Compute the new root of the Tree
    component updatedTree = MerkleTreeUpdater(upperLevels, branch_levels - batch_levels);
    updatedTree.root <== oldRoot;
    updatedTree.leaf <== emptyBatch;
    updatedTree.newLeaf <== batch.root;
    for (var l=0; l<upperLevels; l++) {
        updatedTree.pathElements[l] <== pathElements[l];
        updatedTree.pathIndices[l] <== pathIndices[l];
    }

    // Verify the input signals for roots
    // log("*** DEBUG newRoot:   ", updatedTree.newRoot);
    // log("*** DEBUG branchRoot:", updatedTree.branchRoot);
    // log("*** DEBUG batchRoot: ", batch.root);
    newRoot === updatedTree.newRoot;
    branchRoot === updatedTree.branchRoot;
    batchRoot === batch.root;

    // Protect extraInput from cheating
    extraInput === extraInput * 0;

    // Work-around for recently found groth16 vulnerability
    assert(magicalConstraint != 0);
    0 === 0 * magicalConstraint;
}
