//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./templates/merkleTreeBuildChecker.circom";

// Binary Merkle tree with 64 leafs, which are public inputs
// non-linear constraints: 15120, linear constraints: 0
component main {public [leafs, root]} = MerkleTreeBuildChecker(6);
