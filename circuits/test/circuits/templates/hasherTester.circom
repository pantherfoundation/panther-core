//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../../circuits/templates/hasher.circom";


template HasherTester(nInputs){
    signal input inputs[nInputs];
    signal input hash;

    component hasher = Hasher(nInputs);

    for(var i=0; i<nInputs; i++) {
        hasher.inputs[i] <== inputs[i];
    }

    hash === hasher.out;
}
