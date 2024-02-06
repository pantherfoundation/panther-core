//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

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
    signal enabled_bit_check0[64];
    signal enabled_bit_check1[64];
    for(var i = 0; i < 64; i++) {
        is_zero[i] = IsZero();
        is_zero[i].in <== i - networkId;

        // enabled_bit_check will be something only when is_zero[i].out == 1
        enabled_bit_check0[i] <== is_zero[i].out * n2b_networkIdsBitMap.out[i];
        enabled_bit_check1[i] <== enabled_bit_check0[i] * enabled;
        // make sure that when is_zero[i].out == 1 (bit we interesting in), same bit - n2b_networkIdsBitMap.out[i]
        enabled_bit_check1[i] === is_zero[i].out * enabled;
    }
}
