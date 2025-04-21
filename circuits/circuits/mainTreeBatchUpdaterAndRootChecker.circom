// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./templates/treeBatchUpdaterAndRootChecker.circom";

// It proves insertion of a "batch" of new leafs into the "Bus Tree".
// It verifies post-insertion values of:
// - root of the Bus Tree;
// - root of the Bus Tree's branch containing new leafs only (the "Batch");
// - root of a bigger Bus Tree's branch containing the Batch (the "Branch").
//
// (non-linear constraints: 44313, linear constraints: 0)
component main {
    public [
        oldRoot,             // Root of the Bus tree before the insertion
        newRoot,             // Root of the Bus tree after the insertion
        replacedNodeIndex,   // Index of the leftmost "empty" node
        newLeafsCommitment,  // Commitment to new leafs
        nNonEmptyNewLeafs,   // Number of non-empty new leafs
        batchRoot,           // Root of the Batch
        branchRoot,          // Toot of the Branch
        extraInput,          // Arbitrary data to anchor in the SNARK-proof
        magicalConstraint    // ANY value except 0
    ]
} = TreeBatchUpdaterAndRootChecker(
    26, // tree_levels - depth (number of levels under the root) of the Bus tree
    16, // branch_levels - depth of the Branch
    6,  // batch_levels - depth of the Batch

    // emptyLeaf  - value in an "empty" leaf
    0x667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d,
    // emptyBatch - root of the tree of batch_levels height from empty leafs
    0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69
);
