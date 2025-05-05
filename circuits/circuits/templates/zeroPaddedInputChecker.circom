// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

// Enforces that for `i >= nInputs` all inputs[i] are zero values
template ZeroPaddedInputChecker(max_nInputs, zeroValue){
    signal input inputs[max_nInputs];
    signal input nInputs;

    component n2b_nInputs = Num2Bits(252);
    n2b_nInputs.in <== nInputs;

    assert(max_nInputs<=252);
    component isMax_nInputsLessOrEqualTo252;
    isMax_nInputsLessOrEqualTo252 = LessEqThan(252);
    isMax_nInputsLessOrEqualTo252.in[0] <== max_nInputs;
    isMax_nInputsLessOrEqualTo252.in[1] <== 252;
    isMax_nInputsLessOrEqualTo252.out === 1;

    assert(nInputs<=max_nInputs);
    component isNInputsLessOrEqualToMax_nInputs;
    isNInputsLessOrEqualToMax_nInputs = LessEqThan(252);
    isNInputsLessOrEqualToMax_nInputs.in[0] <== nInputs;
    isNInputsLessOrEqualToMax_nInputs.in[1] <== max_nInputs;
    isNInputsLessOrEqualToMax_nInputs.out === 1;

    component comparators[max_nInputs];
    signal factors[max_nInputs];
    signal expInputs[max_nInputs];

     // Enforce `inputs[i] == (i < nInputs ? inputs[i] : zeroValue)`
    for(var i=0; i<max_nInputs; i++) {
        comparators[i] = LessThan(max_nInputs);
        comparators[i].in[0] <== i;
        comparators[i].in[1] <== nInputs;
        factors[i] <== comparators[i].out;

        expInputs[i] <== inputs[i] * factors[i] + zeroValue * (1 - factors[i]);
        expInputs[i] === inputs[i];
    }
}
