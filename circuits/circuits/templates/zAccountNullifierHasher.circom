// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/poseidon.circom";

template ZAccountNullifierHasher(){
    signal input {sub_order_bj_sf} privKey;
    signal input                   commitment;

    signal output out;

    component noteHasher = Poseidon(2);

    noteHasher.inputs[0] <== privKey;
    noteHasher.inputs[1] <== commitment;

    noteHasher.out ==> out;
}
