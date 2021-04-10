//SPDX-License-Identifier: ISC

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";



template MerkleTreeInclusionProof(n_levels) {
    /*
    Path indices represented as bits of the `pathIndices` signal, one per level,
    from the leaf level in the lowest bit, up to the level preceding the root.
    If the path index for a level is 0, the path element for that level is the
    left node in a pair (if the index is 1, the element is the right one).
    The `pathElements` array of signals sets path elements. The first element
    in the array is a leaf (a pair leaf to the one set by the `leaf` signal).
    */
    signal input leaf;
    signal input pathIndices;
    signal input pathElements[n_levels];

    signal output root;

    component hashers[n_levels];
    component switchers[n_levels];
    component index = Num2Bits(n_levels);
    index.in <== pathIndices;
    // Note: `index.out[0]` gets the leaves level bit

    var levelHash = leaf;

    for (var i = 0; i < n_levels; i++) {
        switchers[i] = Switcher(); // (outL,outR) = sel==0 ? (L,R) : (R,L)
        switchers[i].L <== levelHash;
        switchers[i].R <== pathElements[i];
        switchers[i].sel <== index.out[i];
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== switchers[i].outL;
        hashers[i].inputs[1] <== switchers[i].outR;
        levelHash = hashers[i].out;
    }

    root <== levelHash;
}


template NoteInclusionProver(n_levels) {
    signal input root;
    signal input leaf;
    signal input pathIndices;
    signal input pathElements[n_levels];
    signal input utxoAmount;

	signal output out; // 1 if included or `utxoAmount == 0`

    // compute the root from the Merkle inclusion proof
    component proof = MerkleTreeInclusionProof(n_levels);
    proof.leaf <== leaf;
    proof.pathIndices <== pathIndices;
    for (var i=0; i<n_levels; i++)
        proof.pathElements[i] <== pathElements[i];

    // check if UTXO amount is zero
    component isZeroUtxo = IsZero();
    isZeroUtxo.in <== utxoAmount;

    // verify computed root against provided one if UTXO is non-zero
    component isEqual = IsEqual();
    isEqual.in[0] <== root;
    isEqual.in[1] <== proof.root;

	out <== isEqual.out * (1 - isZeroUtxo.out);
}
