//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../circuits/templates/noteHasher.circom";
include "../../circuits/templates/noteInclusionProver.circom";
include "../../node_modules/circomlib/circuits/babyjub.circom";
// 3,3,16
template TestInclusionProver(nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth) {

    signal input spendPubKey[2];

    signal input amountsOut[nUtxoOut];
    signal input commitmentsOut[nUtxoOut];

    signal input spendPrivKey;
    signal input amountsIn[nUtxoIn];
    signal input token;
    signal input createTime;

    signal input pathElements[nUtxoIn][UtxoMerkleTreeDepth+1]; // extra slot for the third leave
    signal input pathIndexes[nUtxoIn][UtxoMerkleTreeDepth+1];
    signal input merkleRoots[nUtxoIn];
    /*
    for(var i = 0; i < nUtxoIn; i++) {
        for(var j = 0; j < UtxoMerkleTreeDepth+1; j++) {
            log(pathElements[i][j]);
        }
        for(var j = 0; j < UtxoMerkleTreeDepth+1; j++) {
            log(pathIndexes[i][j]);
        }
        log(merkleRoots[i]);
    }
    */
    // [0] - Test public key derive
    component babyPbk = BabyPbk();
    babyPbk.in <== spendPrivKey;
    //log(spendPubKey[0]);
    //log(spendPubKey[1]);
    //log(babyPbk.Ax);
    //log(babyPbk.Ay);
    spendPubKey[0] === babyPbk.Ax;
    spendPubKey[1] === babyPbk.Ay;

    // [1] - Test commitment out creation vs its hash - UTXO out
    component outputNoteHashers[nUtxoOut];
    for(var i = 0; i < nUtxoOut; i++) {
        outputNoteHashers[i] = NoteHasher();
        outputNoteHashers[i].spendPk[0] <== spendPubKey[0];  // use provided pub-key - just in case
        outputNoteHashers[i].spendPk[1] <== spendPubKey[1];  // use provided pub-key - just in case
        outputNoteHashers[i].amount <== amountsOut[i];
        outputNoteHashers[i].token <== token;
        outputNoteHashers[i].createTime <== createTime;
        // verify
        //log(commitmentsOut[i]);
        //log(outputNoteHashers[i].out);
        outputNoteHashers[i].out === commitmentsOut[i];
    }

    // [2] - Test inclusion proof in order to spend UTXOs created in step "[1]"
    component inputNoteHashers[nUtxoIn];
    component inclusionProvers[nUtxoIn];
    for(var i = 0; i < nUtxoIn; i++) {
        // create UTXO input
        inputNoteHashers[i] = NoteHasher();
        inputNoteHashers[i].spendPk[0] <== babyPbk.Ax;
        inputNoteHashers[i].spendPk[1] <== babyPbk.Ay;
        inputNoteHashers[i].amount <== amountsIn[i];
        inputNoteHashers[i].token <== token;
        inputNoteHashers[i].createTime <== createTime;

        // verify - just in case
        inputNoteHashers[i].out === outputNoteHashers[i].out;

        // verify Merkle proofs for input notes
        inclusionProvers[i] = NoteInclusionProver(UtxoMerkleTreeDepth);
        inclusionProvers[i].note <== inputNoteHashers[i].out; // This is leaf in MerkleTree - Poseidon(5) hash of pubKey{Ax,Ay}, amount, token, createTime
        for(var j=0; j < UtxoMerkleTreeDepth+1; j++) {
            inclusionProvers[i].pathElements[j] <== pathElements[i][j];
            inclusionProvers[i].pathIndices[j] <== pathIndexes[i][j];
        }
        inclusionProvers[i].root <== merkleRoots[i];
        inclusionProvers[i].utxoAmount <== amountsIn[i];
    }
}
// NOTE: solidity use TREE_DEPTH = 15 , JS tree.js code in order to generate MT-Path for circom
// must use TREE_DEPTH = 16.
component main {public [merkleRoots]} = TestInclusionProver(3,3,15);
