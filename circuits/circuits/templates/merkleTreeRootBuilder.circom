//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "circomlib/circuits/switcher.circom";
include "./hasher.circom";

template MerkleTreeRootBuilder(levels) {
    signal input leafs[2**levels];
    signal output root;

    var nLeafs = 2**levels;
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
    for (var l=1; l < nNodes; l++) {
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

    root <== nodes[levels - 1].out;
}
