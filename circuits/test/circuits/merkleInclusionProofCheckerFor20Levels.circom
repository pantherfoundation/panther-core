//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./templates/merkleInclusionProofChecker.circom";

// non-linear constraints: 4820, linear constraints: 0
component main {public [leaf, root]} = MerkleInclusionProofChecker(20);
