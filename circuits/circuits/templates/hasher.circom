//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";


template Hasher(nInputs){
    signal input inputs[nInputs];

    signal output out;

    component poseidon = Poseidon(nInputs);

    for(var i=0; i<nInputs; i++) {
        poseidon.inputs[i] <== inputs[i];
    }

    poseidon.out ==> out;
}
