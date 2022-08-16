//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/babyjub.circom";

template TestBabyPbk() {
    signal input spendPrivKey;
    signal input spendPubKey[2];

    component babyPbk = BabyPbk();
    babyPbk.in <== spendPrivKey;

    spendPubKey[0] === babyPbk.Ax;
    spendPubKey[1] === babyPbk.Ay;
}

component main {public [spendPrivKey,spendPubKey]} = TestBabyPbk();