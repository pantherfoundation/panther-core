// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.0.0;

include "../../../circuits/templates/merkleInclusionProof.circom";

template MerkleInclusionProofChecker(levels) {
    signal input leaf;
    signal input pathElements[levels];
    signal input pathIndices[levels];
    signal input root;

    component proof = MerkleInclusionProof(levels);

    proof.leaf <== leaf;
    for (var i = 0; i < levels; i++) {
        proof.pathElements[i] <== pathElements[i];
        proof.pathIndices[i] <== pathIndices[i];
    }

    root === proof.root;
}
