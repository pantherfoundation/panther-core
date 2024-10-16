//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/switcher.circom";
include "./hasher.circom";

template MerkleTreeBuilder(levels) {
    var nLeafs = 2**levels;
    signal input leafs[nLeafs];
    signal output root;

    var nHashes = nLeafs - 1;
    component nodes[nHashes];

    // Iterate through the leafs
    var nextNodeIndex = 0;
    for (var n=0; n<nLeafs; n+=2) {
        nodes[nextNodeIndex] = Hasher(2);
        nodes[nextNodeIndex].inputs[0] <== leafs[n];
        nodes[nextNodeIndex].inputs[1] <== leafs[n+1];
        nextNodeIndex++;
    }

    // Iterate through levels above leafs
    var firstChildNodeIndex = 0;
    var nNodes = nLeafs/2;
    for (var l=1; l < levels; l++) {
        // Iterate through level nodes
        for (var n = 0; n<nNodes; n=n+2) {
            var childNodeIndex = firstChildNodeIndex + n;
            nodes[nextNodeIndex] = Hasher(2);
            nodes[nextNodeIndex].inputs[0] <== nodes[childNodeIndex].out;
            nodes[nextNodeIndex].inputs[1] <== nodes[childNodeIndex + 1].out;
            nextNodeIndex++;
        }
        // For the next level
        firstChildNodeIndex += nNodes;
        nLeafs = nNodes;
        nNodes = nNodes / 2;
    }

    root <== nodes[nHashes - 1].out;
}
