//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../circuits/templates/merkleInclusionProofChecker.circom";

// non-linear constraints: 5784, linear constraints: 0
component main {public [leaf, root]} = MerkleInclusionProofChecker(24);
