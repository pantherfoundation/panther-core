//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";



template MerkleTreeInclusionProof(n_levels) {
    /*
    check https://github.com/pantherprotocol/panther-protocol/blob/triad-tree/docs/triadMerkleTree.md.
    Path indices represented as bits of the `pathIndices` signal, one per level,
    except the leaf level takes 2 bits,
    Apart from leaf level, if the path index for a level is 0, the path element for that level is the
    left node in a pair (if the index is 1, the element is the right one).
    The `pathElements` array of signals sets path elements. The first element
    in the array is a leaf (a pair leaf to the one set by the `leaf` signal).
    */
    signal input leaf;
    signal input pathIndices;
    signal input pathElements[n_levels+1]; // extra slot for third leave

    signal output root;

    component hashers[n_levels];
    component switchers[n_levels];
    component index = Num2Bits(n_levels);
    index.in <== pathIndices;
    // Note: `index.out[0]` gets the leaves level bit

    hashers[0] = Poseidon(3);
    // c = leaf, l pathElements[0], r = pathElements[1];
    // bl = index.out[0], bh = index.out[1]
    // enforece that bh,bl can't be 11
    0 === index.out[0]*index.out[1];
    // n1 is c if bl
    hashers[0].inputs[0] <== leaf + (index.out[0]+index.out[1])*(pathElements[0] - leaf); 
    signal temp;
    temp <== pathElements[0] + index.out[0]*(leaf - pathElements[0]);
    hashers[0].inputs[1] <== temp + index.out[1]*(pathElements[1] - pathElements[0]);
    hashers[0].inputs[2] <== pathElements[1] + index.out[1]*(leaf -pathElements[1]);

    // loop from next levek
    for (var i = 1; i < n_levels; i++) {
        switchers[i] = Switcher(); // (outL,outR) = sel==0 ? (L,R) : (R,L)
        switchers[i].L <== hashers[i-1].out;
        switchers[i].R <== pathElements[i+1];
        switchers[i].sel <== index.out[i];
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== switchers[i].outL;
        hashers[i].inputs[1] <== switchers[i].outR;
    }

    root <== hashers[n_levels-1].out;
}


template NoteInclusionProver(n_levels) {
    signal input root;
    signal input leaf;
    signal input pathIndices;
    signal input pathElements[n_levels+1]; // extra slot for third leave
    signal input utxoAmount;

    // compute the root from the Merkle inclusion proof
    component proof = MerkleTreeInclusionProof(n_levels);
    proof.leaf <== leaf;
    proof.pathIndices <== pathIndices;
    for (var i=0; i<=n_levels; i++)
        proof.pathElements[i] <== pathElements[i];

    // check if UTXO amount is zero
    component isZeroUtxo = IsZero();
    isZeroUtxo.in <== utxoAmount;

    // verify computed root against provided one if UTXO is non-zero
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== root;
    isEqual.in[1] <== proof.root;
    isEqual.enabled <== 1-isZeroUtxo.out;
}
