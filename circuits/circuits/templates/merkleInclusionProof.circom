//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "circomlib/circuits/switcher.circom";
include "./hasher.circom";

template MerkleInclusionProof(levels) {
    signal input          leaf;
    signal input          pathElements[levels];
    signal input {binary} pathIndices[levels];

    signal output root;

    component switchers[levels];
    component hashers[levels];

    // first, compute the node above the leafs
    switchers[0] = Switcher();
    switchers[0].L <== leaf;
    switchers[0].R <== pathElements[0];
    switchers[0].sel <== pathIndices[0];

    hashers[0] = Hasher(2);
    hashers[0].inputs[0] <== switchers[0].outL;
    hashers[0].inputs[1] <== switchers[0].outR;

    // Then iterate over remaining levels up to the root
    for (var i = 1; i < levels; i++) {
        switchers[i] = Switcher();
        switchers[i].L <== hashers[i-1].out;
        switchers[i].R <== pathElements[i];
        switchers[i].sel <== pathIndices[i];

        hashers[i] = Hasher(2);
        hashers[i].inputs[0] <== switchers[i].outL;
        hashers[i].inputs[1] <== switchers[i].outR;
    }

    root <== hashers[levels - 1].out;
}
