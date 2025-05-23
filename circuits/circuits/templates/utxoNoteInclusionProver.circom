// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

template UtxoNoteInclusionProverBinarySelectable(l_levels,m_extraLevels,r_extraLevels) {
    // the middle tree must have no less levels than the left one
    var m_levels = l_levels + m_extraLevels;
    // the right tree must have no less levels than the middle one
    var r_levels = m_levels + r_extraLevels;

    signal input          root[3];
    signal input {binary} treeSelector[2];
    signal input          note;
    signal input {binary} pathIndices[r_levels];
    signal input          pathElements[r_levels];
    signal input          enabled;

    // compute the root from the Merkle inclusion proof
    component proof = MerkleTreeInclusionProofDoubleLeavesSelectable(l_levels,m_extraLevels,r_extraLevels);
    proof.leaf <== note;
    proof.treeSelector[0] <== treeSelector[0];
    proof.treeSelector[1] <== treeSelector[1];
    for (var i = 0; i < r_levels; i++){
        proof.pathIndices[i] <== pathIndices[i];
        proof.pathElements[i] <== pathElements[i];
    }

    // Choose the root to return, based upon `treeSelector`
    component switch = Selector3();
    switch.sel[0] <== treeSelector[0];
    switch.sel[1] <== treeSelector[1];
    switch.L <== root[0];
    switch.M <== root[1];
    switch.R <== root[2];

    // verify computed root against provided one if UTXO is non-zero
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== switch.out;
    isEqual.in[1] <== proof.root;
    isEqual.enabled <== enabled;
}
