//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./merkleInclusionProof.circom";

// It verifies proof of inclusion of a leaf in a (fully balanced) binary Merkle
// tree (the "Tree"), and computes the root of the Tree after the leaf update.
// It also computes the root of a Tree's branch (the "Branch"), the updated leaf
// is a part of.
//
template MerkleTreeUpdater(
    tree_levels,   // depth of the Tree
    branch_levels  // depth of the Branch
) {
    assert(tree_levels > branch_levels);
    //      *  <----- Tree -------+  ----------
    //     / \                    |  top levels
    //    *   *  <--- Branch --+  |  __________
    //   /\   /\               |  |
    //  *  * *  *  <- leafs----+--+


    // The root of the Tree before the update
    // (with the "old" value in the leaf being updated)
    signal input root;

    // "Old" leaf (being updated)
    signal input leaf;
    // New leaf (after the update)
    signal input newLeaf;
    // Path elements (sibling nodes) of the leaf being updated
    signal input pathElements[tree_levels];
    // Path indices of the leaf being updated
    signal input pathIndices[tree_levels];

    // Root of the Tree after the update
    signal output newRoot;

    // Root of the Branch (after the update)
    signal output branchRoot;


    // Verify the Merkle inclusion proof for the leaf
    component oldTree = MerkleInclusionProof(tree_levels);
    oldTree.leaf <== leaf;
    for (var l=0; l<tree_levels; l++) {
        oldTree.pathElements[l] <== pathElements[l];
        oldTree.pathIndices[l] <== pathIndices[l];
    }
    oldTree.root === root;

    // Compute the new root of the Branch
    component newBranch = MerkleInclusionProof(branch_levels);
    newBranch.leaf <== newLeaf;
    for (var l=0; l<branch_levels; l++) {
        newBranch.pathElements[l] <== pathElements[l];
        newBranch.pathIndices[l] <== pathIndices[l];
    }
    branchRoot <== newBranch.root;

    // Compute the new root of the Tree
    var topLevels = tree_levels - branch_levels;
    component updatedTree = MerkleInclusionProof(topLevels);
    updatedTree.leaf <== newBranch.root;
    for (var l=0; l<topLevels; l++) {
        updatedTree.pathElements[l] <== pathElements[branch_levels + l];
        updatedTree.pathIndices[l] <== pathIndices[branch_levels + l];
    }
    newRoot <== updatedTree.root;
}
