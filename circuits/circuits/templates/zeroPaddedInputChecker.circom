//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

// Enforces that for `i >= nInputs` all inputs[i] are zero values
template ZeroPaddedInputChecker(max_nInputs, zeroValue){
    signal input inputs[max_nInputs];
    signal input nInputs;

    assert(max_nInputs<=252);
    assert(nInputs<=max_nInputs);

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
