//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../../node_modules/circomlib/circuits/poseidon.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";
include "../../../node_modules/circomlib/circuits/gates.circom";

template MultiPoseidon(n) {
    signal input inputs[n];
    signal output out;

    component pSingle;

    component pDoubleInputs;
    component pMulti[2];

    if ( n < 6 ) {
        pSingle = Poseidon(n);
        for (var i = 0; i < n; i++) {
            pSingle.inputs[i] <== inputs[i];
        }
        out <== pSingle.out;
    } else {
        pDoubleInputs = Poseidon(2);
        var n1 = n\2;
        var n2 = n-n\2;

        pMulti[0] = MultiPoseidon(n1);
        pMulti[1] = MultiPoseidon(n2);

        for (var i = 0; i < n1; i++) {
            pMulti[0].inputs[i] <== inputs[i];
        }

        for (var i = 0; i < n2; i++) {
            pMulti[1].inputs[i] <== inputs[n1+i];
        }

        pDoubleInputs.inputs[0] <== pMulti[0].out;
        pDoubleInputs.inputs[1] <== pMulti[1].out;

        out <== pDoubleInputs.out;
    }
}
