//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/sha256/sha256.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template SignalsHasher(nSignals) {
    signal input in[nSignals];
    signal output out;

    var nBits = 256;
    component n2b[nSignals];
    component sha256 = Sha256(nSignals*nBits);

    // serialize all input signals into "bits"
    for(var i=0; i<nSignals; i++){
        n2b[i] = Num2Bits(nBits);
        n2b[i].in <== in[i];
        for(var j=0; j<nBits; j++) { 
            var index = nBits*i + (nBits-1) - j;
            sha256.in[index] <== n2b[i].out[j];
        }
    }

    // deserialize output "bits" into (single) output signal
    component b2n = Bits2Num(nBits);
    for (var i = 0; i < nBits; i++) {
        b2n.in[i] <== sha256.out[255-i];
    }
    out <== b2n.out;
}
// SHA256 
template PublicInputHasher(nUtxoIn, nUtxoOut) {
    signal input extraInputsHash; // 256 bit - 0 
    signal input publicToken; // 160 bit - 1
    signal input extAmountIn; // 96 bit - 2
    signal input extAmountOut; // 96 bit - 3
    signal input weightMerkleRoot; // 256 bit  - 4 
    signal input forTxReward; // 40 bit - 5 
    signal input forUtxoReward; // 40 bit - 6
    signal input forDepositReward; // 40 bit - 7 
    signal input spendTime; // 32 bit - 8
    signal input rMerkleRoot; // 256 bit - 9
    signal input rNullifier; // 256 bit - 10
    signal input createTime; // 32 bit - 11
    signal input relayerRewardCipherText[4]; // 256 bit - 12,13,14,15 
    signal input merkleRoots[nUtxoIn]; // 256 bit - 16,17 ( for 2 )
    signal input treeNumbers[nUtxoIn]; // 8 bit - 18,19 ( for 2 )
    signal input nullifiers[nUtxoIn]; // 256 bit - 20,21 ( for 2 )
    signal input commitmentsOut[nUtxoOut]; // 256 bit - 22,23 ( for 2 )

    signal output out;

    var nSignals = 16 + 3*nUtxoIn + nUtxoOut; // 24 
    component hasher = SignalsHasher(nSignals);

    hasher.in[0] <== extraInputsHash; // 0
    hasher.in[1] <== publicToken;
    hasher.in[2] <== extAmountIn;
    hasher.in[3] <== extAmountOut;
    hasher.in[4] <== weightMerkleRoot;
    hasher.in[5] <== forTxReward;
    hasher.in[6] <== forUtxoReward;
    hasher.in[7] <== forDepositReward;
    hasher.in[8] <== spendTime;
    hasher.in[9] <== rMerkleRoot;
    hasher.in[10] <== rNullifier;
    hasher.in[11] <== createTime; // 11 
    var shift = 12; 
    for(var i=0; i< 4; i++) // 12,13,14,15 
        hasher.in[shift + i] <== relayerRewardCipherText[i];

    shift += 4;
    for(var i=0; i<nUtxoIn; i++) { // 16,17,18; 19,20,21; 22,23,24  
        hasher.in[shift+i] <== merkleRoots[i];
        hasher.in[shift+nUtxoIn+i] <== nullifiers[i];
        hasher.in[shift+ 2*nUtxoIn+i] <== treeNumbers[i];
    }
    shift += 3*nUtxoIn;
    for(var i=0; i<nUtxoOut; i++) // 25 
        hasher.in[shift+i] <== commitmentsOut[i];
    
    out <== hasher.out;
}

// Measurements Games 
template PublicInputHasherOpt(nUtxoIn, nUtxoOut) {
    signal input extraInputsHash; // 256 bit - 0 
    signal input publicToken; // 160 bit - 1
    signal input extAmountIn; // 96 bit - 2
    signal input extAmountOut; // 96 bit - 3
    signal input weightMerkleRoot; // 256 bit  - 4 
    signal input forTxReward; // 40 bit - 5 
    signal input forUtxoReward; // 40 bit - 6
    signal input forDepositReward; // 40 bit - 7 
    signal input spendTime; // 32 bit - 8
    signal input rMerkleRoot; // 256 bit - 9
    signal input rNullifier; // 256 bit - 10
    signal input createTime; // 32 bit - 11
    signal input relayerRewardCipherText[4]; // 256 bit - 12,13,14,15 
    signal input merkleRoots[nUtxoIn]; // 256 bit - 16,17 ( for 2 )
    signal input treeNumbers[nUtxoIn]; // 8 bit - 18,19 ( for 2 )
    signal input nullifiers[nUtxoIn]; // 256 bit - 20,21 ( for 2 )
    signal input commitmentsOut[nUtxoOut]; // 256 bit - 22,23 ( for 2 )

    signal output out;
    
    component hasher = SignalsHasher(1);
    hasher.in[0] <== extraInputsHash;

    out <== hasher.out;
} 

// Packeging specific - not general 
template SignalsHasherPacked(nSignals, nSha256InBits) {
    signal input in[nSignals];
    signal output out;

    component n2b[nSignals];
    component sha256 = Sha256( nSha256InBits ); // nSignals*256);

    // serialize all input signals into "bits"
    var shift = 0;
    for(var i=0; i<nSignals; i++){
        if (i == 1) { // 160 bit case 
            var nBits = 160;
            n2b[i] = Num2Bits(nBits);
            n2b[i].in <== in[i];
            for(var j=0; j<nBits; j++) {
                var index = shift + (nBits-1) - j;
                sha256.in[index] <== n2b[i].out[j];
            }
            shift += nBits;
        } 
        else if ( (i == 2) || (i == 3) ) { // 96 bit case 
            var nBits = 96;
            n2b[i] = Num2Bits(nBits);
            n2b[i].in <== in[i];
            for(var j=0; j<nBits; j++) { 
                var index = shift + (nBits-1) - j;
                sha256.in[index] <== n2b[i].out[j];
            }
            shift += nBits;
        } 
        else if ( (i == 5) || (i == 6) || (i == 7) ) { // 40 bit case 
            var nBits = 40;
            n2b[i] = Num2Bits(nBits);
            n2b[i].in <== in[i];
            for(var j=0; j<nBits; j++) { 
                var index = shift + (nBits-1) - j;
                sha256.in[index] <== n2b[i].out[j];
            }
            shift += nBits;
        } 
        else if ( (i == 8) || (i == 11) ) { // 32 bit case 
            var nBits = 32;
            n2b[i] = Num2Bits(nBits);
            n2b[i].in <== in[i];
            for(var j=0; j<nBits; j++) { 
                var index = shift + (nBits-1) - j;
                sha256.in[index] <== n2b[i].out[j];
            }
            shift += nBits;
        }
        else if ( (i == 18) || (i == 19) ) { // 8 bit case - for nUtxoIn = 2  
            var nBits = 8;
            n2b[i] = Num2Bits(nBits);
            n2b[i].in <== in[i];
            for(var j=0; j<nBits; j++) { 
                var index = shift + (nBits-1) - j;
                sha256.in[index] <== n2b[i].out[j];
            }
            shift += nBits;
        } 
        else { // default case of 256 bit per signal  
            var nBits = 256;
            n2b[i] = Num2Bits(nBits);
            n2b[i].in <== in[i];
            for(var j=0; j<nBits; j++) { 
                var index = shift + (nBits-1) - j;
                sha256.in[index] <== n2b[i].out[j];
            }
            shift += nBits;
        }
    }

    // deserialize output "bits" into (single) output signal
    component b2n = Bits2Num(256);
    for (var i = 0; i < 256; i++) {
        b2n.in[i] <== sha256.out[255-i];
    }
    out <== b2n.out;
}
// FIXME: Support only nUtxoIn == nUtxoOut == 2
template PublicInputHasherTripplePoseidon(nUtxoIn, nUtxoOut) {
    signal input extraInputsHash; // 256 bit - 0 
    signal input publicToken; // 160 bit - 1
    signal input extAmountIn; // 96 bit - 2
    signal input extAmountOut; // 96 bit - 3
    signal input weightMerkleRoot; // 256 bit  - 4 
    signal input forTxReward; // 40 bit - 5 
    signal input forUtxoReward; // 40 bit - 6
    signal input forDepositReward; // 40 bit - 7 
    signal input spendTime; // 32 bit - 8
    signal input rMerkleRoot; // 256 bit - 9
    signal input rNullifier; // 256 bit - 10
    signal input createTime; // 32 bit - 11
    signal input relayerRewardCipherText[4]; // 256 bit - 12,13,14,15 --- can be decreased to 2x257
    signal input merkleRoots[nUtxoIn]; // 256 bit - 16,17 ( for 2 )
    signal input treeNumbers[nUtxoIn]; // 24 bit - 18,19 ( for 2 )   
    signal input nullifiers[nUtxoIn]; // 256 bit - 20,21 ( for 2 )
    signal input commitmentsOut[nUtxoOut]; // 256 bit - 22,23 ( for 2 )

    signal output out;
    
    assert(nUtxoIn == 2);
    assert(nUtxoOut == 2);

    component hasher1 = Poseidon(5); 
    component hasher2 = Poseidon(5); 
    component hasher3 = Poseidon(5); 
    component hasher4 = Poseidon(3); 

    // ------------ NO PACK --------------- // 
    hasher1.inputs[0] <== extraInputsHash; 
    hasher1.inputs[1] <== weightMerkleRoot;
    hasher1.inputs[2] <== rMerkleRoot;
    hasher1.inputs[3] <== rNullifier;
    hasher1.inputs[4] <== relayerRewardCipherText[0];
    
    hasher2.inputs[0] <== relayerRewardCipherText[2]; // DON FORGET TO PACK BITS 
    //hasher2.inputs[1] <== relayerRewardCipherText[i];
    //hasher2.inputs[2] <== relayerRewardCipherText[i];
    hasher2.inputs[1] <== merkleRoots[0]; // i = 0 : 8, i = 1 : 9
    hasher2.inputs[2] <== nullifiers[0]; // i = 0 : 10, i = 1 : 11
    hasher2.inputs[3] <== merkleRoots[1]; // i = 0 : 8, i = 1 : 9
    hasher2.inputs[4] <== nullifiers[1]; // i = 0 : 10, i = 1 : 11

    hasher3.inputs[0] <== commitmentsOut[0];
    hasher3.inputs[1] <== commitmentsOut[1];

    // ------------ PACK ------------ // 
    // [1] - we will have here aditional space of 96 bits if needed 
    hasher3.inputs[2] <== publicToken; // 14  
    
    // [2] - extAmountIn, extAmountOut 
    component n2b_eIn = Num2Bits(96);
    n2b_eIn.in <== extAmountIn;
    
    component n2b_eOut = Num2Bits(96);
    n2b_eOut.in <== extAmountOut;
    
    component b2n_eInOut = Bits2Num(2*96);
    for(var i = 0; i < 96; i++) { 
        b2n_eInOut.in[i] <== n2b_eIn.out[i];
        b2n_eInOut.in[96 + i] <== n2b_eOut.out[i];
    }

    hasher3.inputs[3] <== b2n_eInOut.out;  
    
    // [3] - forTxReward, forUtxoReward, forDepositReward, spendTime, createTime, treeNumbers 
    component n2b_forTxReward = Num2Bits(40);
    n2b_forTxReward.in <== forTxReward;

    component n2b_forUtxoReward = Num2Bits(40);
    n2b_forUtxoReward.in <== forUtxoReward;

    component n2b_forDepositReward = Num2Bits(40);
    n2b_forDepositReward.in <== forDepositReward;

    component n2b_spendTime = Num2Bits(32);
    n2b_spendTime.in <== spendTime;

    component n2b_createTime = Num2Bits(32);
    n2b_createTime.in <== createTime;

    component n2b_treeNumbers[nUtxoIn]; 

    for(var i = 0; i < nUtxoIn; i++) {
        n2b_treeNumbers[i] = Num2Bits(24);
        n2b_treeNumbers[i].in <== treeNumbers[i];
    }
    
    component moduloTwo1 = AND(); // number % 2 == number & 1
    moduloTwo1.a <== relayerRewardCipherText[1];
    moduloTwo1.b <== 1;
    component n2b_Ay1 = Num2Bits(1);
    n2b_Ay1.in <== moduloTwo1.out;

    component moduloTwo2 = AND(); // number % 2 == number & 1
    moduloTwo2.a <== relayerRewardCipherText[3];
    moduloTwo2.b <== 1;
    component n2b_Ay2 = Num2Bits(1);
    n2b_Ay2.in <== moduloTwo2.out;

    var nBits = 40+40+40+32+32+nUtxoIn*24+2; // 40,40,40 32,32, 24,24 1,1 
    component b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs = Bits2Num(nBits);

    var shift2 = 0;
    for(var i = 0; i < 40; i++) {
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+i] <== n2b_forTxReward.out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+40+i] <== n2b_forUtxoReward.out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+40+40+i] <== n2b_forDepositReward.out[i];   
    }
    shift2 += 3*40;
    for(var i = 0; i < 32; i++) {
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+i] <== n2b_spendTime.out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+32+i] <== n2b_createTime.out[i];   
    }
    shift2 += 2*32;
    for(var i = 0; i < 24; i++) { 
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+i] <== n2b_treeNumbers[0].out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+24+i] <== n2b_treeNumbers[1].out[i];   
    }
    
    shift2 += 2*24;
    b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+0] <== n2b_Ay1.out[0];   
    b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.in[shift2+1] <== n2b_Ay2.out[0];   
    
    hasher3.inputs[4] <== b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers_cipherTest_signs.out; 
    
    hasher4.inputs[0] <== hasher1.out;
    hasher4.inputs[1] <== hasher2.out;
    hasher4.inputs[2] <== hasher3.out;

    out <== hasher4.out;
}
// FIXME: Support only nUtxoIn == nUtxoOut == 2
template PublicInputHasherDoublePoseidon(nUtxoIn, nUtxoOut) {
    signal input extraInputsHash; // 256 bit - 0 
    signal input publicToken; // 160 bit - 1
    signal input extAmountIn; // 96 bit - 2
    signal input extAmountOut; // 96 bit - 3
    signal input weightMerkleRoot; // 256 bit  - 4 
    signal input forTxReward; // 40 bit - 5 
    signal input forUtxoReward; // 40 bit - 6
    signal input forDepositReward; // 40 bit - 7 
    signal input spendTime; // 32 bit - 8
    signal input rMerkleRoot; // 256 bit - 9
    signal input rNullifier; // 256 bit - 10
    signal input createTime; // 32 bit - 11
    signal input relayerRewardCipherText[4]; // 256 bit - 12,13,14,15 --- can be decreased to 2x257
    signal input merkleRoots[nUtxoIn]; // 256 bit - 16,17 ( for 2 )
    signal input treeNumbers[nUtxoIn]; // 24 bit - 18,19 ( for 2 )   
    signal input nullifiers[nUtxoIn]; // 256 bit - 20,21 ( for 2 )
    signal input commitmentsOut[nUtxoOut]; // 256 bit - 22,23 ( for 2 )

    signal output out;

    assert(nUtxoIn == 2);
    assert(nUtxoOut == 2);
    
    component hasher = Poseidon(16); // SignalsHasher(nSignals, nSha256InBits);

    hasher.inputs[0] <== extraInputsHash; // 0
    hasher.inputs[1] <== publicToken;
    hasher.inputs[2] <== extAmountIn;
    hasher.inputs[3] <== extAmountOut;
    hasher.inputs[4] <== weightMerkleRoot;
    hasher.inputs[5] <== forTxReward;
    hasher.inputs[6] <== forUtxoReward;
    hasher.inputs[7] <== forDepositReward;
    hasher.inputs[8] <== spendTime;
    hasher.inputs[9] <== rMerkleRoot;
    hasher.inputs[10] <== rNullifier;
    hasher.inputs[11] <== createTime; // 11 
    var shift = 12; 
    for(var i=0; i< 4; i++) // 12,13,14,15 
        hasher.inputs[shift + i] <== relayerRewardCipherText[i];

    component hasher2 = Poseidon(3*nUtxoIn+nUtxoOut+1); // SignalsHasher(nSignals, nSha256InBits);
    shift = 0;
    for(var i=0; i<nUtxoIn; i++) { // 16,17,18; 19,20,21; 22,23,24  
        hasher2.inputs[shift+i] <== merkleRoots[i];
        hasher2.inputs[shift+nUtxoIn+i] <== nullifiers[i];
        hasher2.inputs[shift+ 2*nUtxoIn+i] <== treeNumbers[i];
    }
    shift += 3*nUtxoIn;
    for(var i=0; i<nUtxoOut; i++) // 25 
        hasher2.inputs[shift+i] <== commitmentsOut[i];
    shift += nUtxoOut;
    hasher2.inputs[shift] <== hasher.out;
    //hasher2.out === extraInputsHash; // this line is for tests - if double poseidon will be used we need to add second hash 
    out <== hasher2.out;
}
// FIXME: Support only nUtxoIn == nUtxoOut == 2
template PublicInputHasherPacked(nUtxoIn, nUtxoOut) {
    signal input extraInputsHash; // 256 bit - 0 
    signal input publicToken; // 160 bit - 1
    signal input extAmountIn; // 96 bit - 2
    signal input extAmountOut; // 96 bit - 3
    signal input weightMerkleRoot; // 256 bit  - 4 
    signal input forTxReward; // 40 bit - 5 
    signal input forUtxoReward; // 40 bit - 6
    signal input forDepositReward; // 40 bit - 7 
    signal input spendTime; // 32 bit - 8
    signal input rMerkleRoot; // 256 bit - 9
    signal input rNullifier; // 256 bit - 10
    signal input createTime; // 32 bit - 11
    signal input relayerRewardCipherText[4]; // 256 bit - 12,13,14,15 
    signal input merkleRoots[nUtxoIn]; // 256 bit - 16,17 ( for 2 )
    signal input treeNumbers[nUtxoIn]; // 8 bit - 18,19 ( for 2 )
    signal input nullifiers[nUtxoIn]; // 256 bit - 20,21 ( for 2 )
    signal input commitmentsOut[nUtxoOut]; // 256 bit - 22,23 ( for 2 )

    signal output out;

    assert(nUtxoIn == 2);
    assert(nUtxoOut == 2);

    var nSignals = 16 + 3*nUtxoIn + nUtxoOut; // 24 
    var nSha256InBits = 256 * nSignals - (256 - 160) - 2*(256 - 96) -  3*(256 - 40) - 2*(256 - 32) - nUtxoIn*(256 - 8);  
    component hasher = SignalsHasherPacked(nSignals, nSha256InBits);

    hasher.in[0] <== extraInputsHash; // 0
    hasher.in[1] <== publicToken;
    hasher.in[2] <== extAmountIn;
    hasher.in[3] <== extAmountOut;
    hasher.in[4] <== weightMerkleRoot;
    hasher.in[5] <== forTxReward;
    hasher.in[6] <== forUtxoReward;
    hasher.in[7] <== forDepositReward;
    hasher.in[8] <== spendTime;
    hasher.in[9] <== rMerkleRoot;
    hasher.in[10] <== rNullifier;
    hasher.in[11] <== createTime; // 11 
    var shift = 12; 
    for(var i=0; i< 4; i++) // 12,13,14,15 
        hasher.in[shift + i] <== relayerRewardCipherText[i];

    shift += 4;
    for(var i=0; i<nUtxoIn; i++) { // 16,17,18; 19,20,21; 22,23,24  
        hasher.in[shift+i] <== merkleRoots[i];
        hasher.in[shift+nUtxoIn+i] <== nullifiers[i];
        hasher.in[shift+ 2*nUtxoIn+i] <== treeNumbers[i];
    }
    shift += 3*nUtxoIn;
    for(var i=0; i<nUtxoOut; i++) // 25 
        hasher.in[shift+i] <== commitmentsOut[i];
    
    out <== hasher.out;
}
// FIXME: Support only nUtxoIn == nUtxoOut == 2
template PublicInputHasherPoseidon(nUtxoIn, nUtxoOut) {
    // no pack 
    signal input extraInputsHash; // 256 bit - 0 
    signal input weightMerkleRoot; // 256 bit  - 1
    signal input rMerkleRoot; // 256 bit - 2
    signal input rNullifier; // 256 bit - 3
    signal input relayerRewardCipherText[4]; // 256 bit - 4,5,6,7 
    signal input merkleRoots[nUtxoIn]; // 256 bit - 8,9 ( for 2 )
    signal input nullifiers[nUtxoIn]; // 256 bit - 10,11 ( for 2 )
    signal input commitmentsOut[nUtxoOut]; // 256 bit - 12,13 ( for 2 )

    // pack one to one 
    signal input publicToken; // 160 bit - 14

    // pack two to one 
    signal input extAmountIn; // 96 bit - 15
    signal input extAmountOut; // 96 bit - 15
    
    // pack all these to one 
    signal input forTxReward; // 40 bit - 16
    signal input forUtxoReward; // 40 bit - 16
    signal input forDepositReward; // 40 bit - 16 
    signal input spendTime; // 32 bit - 16
    signal input createTime; // 32 bit - 16
    signal input treeNumbers[nUtxoIn]; // 8 bit - 16,16 ( for 2 )
    
    signal output out;
    
    assert(nUtxoIn == 2);
    assert(nUtxoOut == 2);
    
    // for Posidon 17 is a MAX 
    var nSignals = 16; 
    component hasher = Poseidon(nSignals);
    // ------------ NO PACK --------------- // 
    hasher.inputs[0] <== extraInputsHash; 
    hasher.inputs[1] <== weightMerkleRoot;
    hasher.inputs[2] <== rMerkleRoot;
    hasher.inputs[3] <== rNullifier;
    
    var shift = 4; 
    for(var i=0; i<4; i++) // 4,5,6,7
        hasher.inputs[shift + i] <== relayerRewardCipherText[i];

    shift += 4; // 8
    for(var i=0; i<nUtxoIn; i++) { // 8,9,10,11  
        hasher.inputs[shift+i] <== merkleRoots[i]; // i = 0 : 8, i = 1 : 9
        hasher.inputs[shift+nUtxoIn+i] <== nullifiers[i]; // i = 0 : 10, i = 1 : 11
    }
    shift += 2*nUtxoIn; // 12 
    for(var i=0; i<nUtxoOut; i++) // 12,13 
        hasher.inputs[shift+i] <== commitmentsOut[i];
    
    // ------------ PACK ------------ // 
    // [1] - we will have here aditional space of 96 bits if needed 
    shift += nUtxoOut; // 14 
    hasher.inputs[shift] <== publicToken; // 14  
    
    // [2] - extAmountIn, extAmountOut 
    component n2b_eIn = Num2Bits(96);
    n2b_eIn.in <== extAmountIn;
    
    component n2b_eOut = Num2Bits(96);
    n2b_eOut.in <== extAmountOut;
    
    component b2n_eInOut = Bits2Num(2*96);
    for(var i = 0; i < 96; i++) { 
        b2n_eInOut.in[i] <== n2b_eIn.out[i];
        b2n_eInOut.in[96 + i] <== n2b_eOut.out[i];
    }

    shift += 1; // 15 
    hasher.inputs[15] <== b2n_eInOut.out; // 15 
    
    // [3] - forTxReward, forUtxoReward, forDepositReward, spendTime, createTime, treeNumbers 
    component n2b_forTxReward = Num2Bits(40);
    n2b_forTxReward.in <== forTxReward;

    component n2b_forUtxoReward = Num2Bits(40);
    n2b_forUtxoReward.in <== forUtxoReward;

    component n2b_forDepositReward = Num2Bits(40);
    n2b_forDepositReward.in <== forDepositReward;

    component n2b_spendTime = Num2Bits(32);
    n2b_spendTime.in <== spendTime;

    component n2b_createTime = Num2Bits(32);
    n2b_createTime.in <== createTime;

    component n2b_treeNumbers[nUtxoIn]; 

    for(var i = 0; i < nUtxoIn; i++) {
        n2b_treeNumbers[i] = Num2Bits(8);
        n2b_treeNumbers[i].in <== treeNumbers[i];
    }

    var nBits = 40+40+40+32+32+nUtxoIn*8;
    component b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers = Bits2Num(nBits);

    var shift2 = 0;
    for(var i = 0; i < 40; i++) {
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+i] <== n2b_forTxReward.out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+40+i] <== n2b_forUtxoReward.out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+40+40+i] <== n2b_forDepositReward.out[i];   
    }
    shift2 += 3*40;
    for(var i = 0; i < 32; i++) {
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+i] <== n2b_spendTime.out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+32+i] <== n2b_createTime.out[i];   
    }
    shift2 += 2*32;
    for(var i = 0; i < 8; i++) { // fix for nUtxoIn != 2 
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+i] <== n2b_treeNumbers[0].out[i];   
        b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.in[shift2+8+i] <== n2b_treeNumbers[1].out[i];   
    }

    //shift += 1; // 16 
    //hasher.inputs[16] <== b2n_forTxReward_Utxo_Deposit_spendTime_createTime_treeNumbers.out; // 16 
    
    out <== hasher.out;
}