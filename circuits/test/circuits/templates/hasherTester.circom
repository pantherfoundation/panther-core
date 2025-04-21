// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
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
