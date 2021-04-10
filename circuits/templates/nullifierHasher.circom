//SPDX-License-Identifier: ISC

include "../../node_modules/circomlib/circuits/poseidon.circom";


template NullifierHasher(){
    signal input spendPrivKey;
    signal input leafId;

    signal output out;

    component noteHasher = Poseidon(2);

    noteHasher.inputs[0] <== spendPrivKey;
    noteHasher.inputs[1] <== leafId;

    noteHasher.out ==> out;
}
