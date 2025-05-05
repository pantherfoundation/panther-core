// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/poseidon.circom";

template Hasher(nInputs){
    signal input inputs[nInputs];

    signal output out;

    component poseidon = Poseidon(nInputs);

    for(var i=0; i<nInputs; i++) {
        poseidon.inputs[i] <== inputs[i];
    }

    poseidon.out ==> out;
}
