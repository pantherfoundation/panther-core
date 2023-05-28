//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./templates/partiallyFilledChainedBatchUpdaterAndNewRootChecker.circom";

// It proves updating the 26-level binary Merkle tree with the batch of up to 64 new leafs.
// (non-linear constraints: 44293, linear constraints: 0)
component main {
    public [
        newLeafsCommitment,
        root,
        replacePathIndices,
        newRoot
    ]
} = PartiallyFilledChainedBatchUpdaterAndNewRootChecker(
    26, // depth of (number of levels under the root in) the tree being updated
    6,  // depth of (number of levels under the root in) the subtree with new leafs
    0x667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d // zeroValue
);
