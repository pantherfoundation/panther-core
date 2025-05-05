// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./utils.circom";

include "./hasher.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

// It computes the root of the degenerate binary merkle tree (aka "chain")
// - i.e. for the tree of this kind (e.g. nInputs = 4):
//     root
//      /\
//     /\ 3
//    /\ 2
//   0  1
// - and the number of (not-ignored) inputs may vary:
//  0 < nInputs =< max_nInputs
//
template PartiallyFilledChainBuilder(max_nInputs){
    signal input inputs[max_nInputs];
    signal input nInputs;

    signal output out;

    assert(0 < max_nInputs <= 252);

    assert(nInputs > 0);
    component lessThen = LessThanWhenEnabled(8);
    lessThen.in[0] <== 0;
    lessThen.in[1] <== nInputs;
    lessThen.enabled <== 1;

    assert(nInputs <= max_nInputs);
    component lessThenEq = LessEqThanWhenEnabled(8);
    lessThenEq.in[0] <== nInputs;
    lessThenEq.in[1] <== max_nInputs;
    lessThenEq.enabled <== 1;

    component hasher[max_nInputs-1];
    component comparators[max_nInputs-1];

    signal interimHashes[max_nInputs];
    signal factors[max_nInputs-1];
    signal accumulator[max_nInputs];

    // First, let's process inputs[0]
    component isSingleLeafTree = IsEqual();
    isSingleLeafTree.in[0] <== nInputs;
    isSingleLeafTree.in[1] <== 1;
    interimHashes[0] <== inputs[0];
    // Root of the tree with a single leaf only equals to the leaf
    accumulator[0] <== 0 + inputs[0]*isSingleLeafTree.out;

    for(var i = 0; i < max_nInputs-1; i++) {
        // Let's process inputs[nextInd] signal
        var nextInd = i+1;
        hasher[i] = Hasher(2);
        hasher[i].inputs[0] <== interimHashes[i];
        hasher[i].inputs[1] <== inputs[nextInd];
        interimHashes[nextInd] <== hasher[i].out;

        // factors[i] := (nextInd+1 == nInputs) ? 1 : 0;
        comparators[i] = IsEqual();
        comparators[i].in[0] <== nextInd+1;
        comparators[i].in[1] <== nInputs;
        factors[i] <== comparators[i].out;

        accumulator[nextInd] <== accumulator[i] + hasher[i].out*factors[i];
    }

    out <== accumulator[max_nInputs-1];
}
