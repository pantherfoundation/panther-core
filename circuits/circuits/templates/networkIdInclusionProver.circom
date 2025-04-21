// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

/*
This template checks if the Network is with a specific ID is enabled by the protocol or not.

@input signals:
1. enabled - boolean value for enabling and disabling the check
2. networkId - unique ID given to each network
3. networkIdsBitMap - map of all the network supported by the protocol
*/
template NetworkIdInclusionProver(){
    signal input enabled;
    signal input networkId;         // 6 bit - power of 2
    signal input networkIdsBitMap;  // 64 bit

    // [0] - Check only single bit is up
    assert(networkId < 64);

    // switch-on single bit
    component n2b_networkIdsBitMap = Num2Bits(64);
    n2b_networkIdsBitMap.in <== networkIdsBitMap;

    component is_zero[64];
    signal enabled_if[64];

    for(var i = 0; i < 64; i++) {
        is_zero[i] = IsZero();
        is_zero[i].in <== i - networkId;
        enabled_if[i] <== is_zero[i].out * enabled;

        // enabled_if[i] == is_zero[i].out == 1 only when i == networkId & enabled != 0 --> same bit in networkIdsBitMap needs to be 1
        // make sure that when is_zero[i].out == 1 (bit we are interesting in), same bit - n2b_networkIdsBitMap.out[i] should be 1
        enabled_if[i] * n2b_networkIdsBitMap.out[i] === enabled_if[i];
    }
}
