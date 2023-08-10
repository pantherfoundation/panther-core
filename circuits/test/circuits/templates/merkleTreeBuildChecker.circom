//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../../circuits/templates/merkleTreeBuilder.circom";


template MerkleTreeBuildChecker(levels){
    var nLeafs = 2**levels;

    signal input leafs[nLeafs];
    signal input root;

    component builder = MerkleTreeBuilder(levels);

    for(var i=0; i<nLeafs; i++) {
        builder.leafs[i] <== leafs[i];
    }

    builder.root === root;
}
