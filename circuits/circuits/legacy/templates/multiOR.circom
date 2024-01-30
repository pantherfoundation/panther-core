//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../../node_modules/circomlib/circuits/poseidon.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";
include "../../../node_modules/circomlib/circuits/gates.circom";

template MultiOR(n) {
    signal input in[n];
    signal output out;
    component ors[2];
    signal or1,or2;
    if (n==1) {
        out <== in[0];
    } else if (n==2) {
        or1 <-- in[0] | in[1];
        out <== or1;
    } else {
        var n1 = n\2;
        var n2 = n-n\2;
        ors[0] = MultiOR(n1);
        ors[1] = MultiOR(n2);
        var i;
        for (i=0; i<n1; i++) ors[0].in[i] <== in[i];
        for (i=0; i<n2; i++) ors[1].in[i] <== in[n1+i];
        or2 <-- ors[0].out | ors[1].out;
        out <== or2;
    }
}
