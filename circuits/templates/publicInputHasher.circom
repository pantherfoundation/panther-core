//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/sha256/sha256.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";


template SignalsHasher(nSignals) {
    signal input in[nSignals];
    signal output out;

    component n2b[nSignals];
    component sha256 = Sha256(nSignals*256);

    // serialize all input signals into "bits"
    for(var i=0; i<nSignals; i++){
        n2b[i] = Num2Bits(256);
        n2b[i].in <== in[i];
        for(var j=0; j<256; j++)
            sha256.in[i*256+255-j] <== n2b[i].out[j];
    }

    // deserialize output "bits" into (single) output signal
    component b2n = Bits2Num(256);
    for (var i = 0; i < 256; i++) {
        b2n.in[i] <== sha256.out[255-i];
    }
    out <== b2n.out;
}


template PublicInputHasher(nUtxoIn, nUtxoOut) {
    signal input extraInputsHash;
    signal input publicToken;
    signal input extAmountIn;
    signal input extAmountOut;
    signal input tokenMerkleRoot;
    signal input forTxReward;
    signal input forUtxoReward;
    signal input forDepositReward;
    signal input spendTime;
    signal input rMerkleRoot;
    signal input rNullifier;
    signal input createTime;
    signal input relayerRewardCipherText[4];
    signal input merkleRoots[nUtxoIn];
    signal input nullifiers[nUtxoIn];
    signal input commitmentsOut[nUtxoOut];

    signal output out;


    var nSignals = 16 + 2*nUtxoIn + nUtxoOut;
    component hasher = SignalsHasher(nSignals);

    hasher.in[0] <== extraInputsHash;
    hasher.in[1] <== publicToken;
    hasher.in[2] <== extAmountIn;
    hasher.in[3] <== extAmountOut;
    hasher.in[4] <== tokenMerkleRoot;
    hasher.in[5] <== forTxReward;
    hasher.in[6] <== forUtxoReward;
    hasher.in[7] <== forDepositReward;
    hasher.in[8] <== spendTime;
    hasher.in[9] <== rMerkleRoot;
    hasher.in[10] <== rNullifier;
    hasher.in[11] <== createTime;
    var shift = 12; 
    for(var i=0; i< 4; i++)
        hasher.in[shift + i] <== relayerRewardCipherText[i];

    shift += 4;
    for(var i=0; i<nUtxoIn; i++) {
        hasher.in[shift+i] <== merkleRoots[i];
        hasher.in[shift+nUtxoIn+i] <== nullifiers[i];
    }
    shift += 2*nUtxoIn;
    for(var i=0; i<nUtxoOut; i++)
        hasher.in[shift+i] <== commitmentsOut[i];
    
    out <== hasher.out;
}
