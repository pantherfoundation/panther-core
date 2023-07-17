//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./multiPoseidon.circom";
include "./multiOR.circom";

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

template PublicInputHasherExtended( nUtxoIn,
                                    nUtxoOut,
                                    nZrDataEscrow,
                                    nDataEscrow,
                                    nDaoDataEscrow ) {
    signal input extraInputsHash;                                           // 256 bit
    signal input publicZAsset;                                              // 160 bit
    signal input depositAmount;                                             // 64 bit
    signal input withdrawAmount;                                            // 64 bit
    signal input zAssetMerkleRoot;                                          // 256 bit
    signal input forTxReward;                                               // 40 bit
    signal input forUtxoReward;                                             // 40 bit
    signal input forDepositReward;                                          // 40 bit
    signal input spendTime;                                                 // 32 bit
    signal input utxoInMerkleRoot[nUtxoIn];                                 // 256 bit
    signal input utxoInTreeNumber[nUtxoIn];                                 // 24 bit
    signal input utxoInNullifier[nUtxoIn];                                  // 256 bit
    signal input zAccountUtxoInMerkleRoot;                                  // 256 bit
    signal input zAccountUtxoInTreeNumber;                                  // 24 bit
    signal input zAccountUtxoInNullifier;                                   // 256 bit
    signal input zAccountBlackListMerkleRoot;                               // 256 bit
    signal input zoneRecordMerkleRoot;                                      // 256 bit
    signal input zoneRecordDataEscrowEphimeralPubKey[2];                    // 256 bit - only `x` will be taken
    signal input zoneRecordDataEscrowEncryptedMessage[nZrDataEscrow][2];    // 256 bit - only `x` will be taken
    signal input kytSignedMessageHash;                                      // 256 bit
    signal input kycKytMerkleRoot;                                          // 256 bit
    signal input dataEscrowEphimeralPubKey[2];                              // 256 bit - only `x` will be taken
    signal input dataEscrowEncryptedMessage[nDataEscrow][2];                // 256 bit - only `x` will be taken
    signal input daoDataEscrowPubKey[2];                                    // 256 bit - only `x` will be taken
    signal input daoDataEscrowEphimeralPubKey[2];                           // 256 bit - only `x` will be taken
    signal input daoDataEscrowEncryptedMessage[nDaoDataEscrow][2];          // 256 bit - only `x` will be taken
    signal input utxoOutCreateTime;                                         // 32 bit
    signal input utxoOutOriginNetworkId[nUtxoOut];                          // 6 bit
    signal input utxoOutCommitments[nUtxoOut];                              // 256 bit
    signal input zAccountUtxoOutCommitment;                                 // 256 bit
    signal input chargedAmountZkp;                                          // 32 bit

    signal output out;

    // this is full size include `x,y` coordinates
    // var n = 5 + 16     + nUtxoIn + nUtxoIn + (2 * nZrDataEscrow) + (2 * nDataEscrow) + (2 * nDaoDataEscrow) + nUtxoOut;
    // this is the size excluded `y` coordinate: `5 packed`, `5 rare`, `8 regular` and `parameter dependent`
    var n    = 5 + 5 + 8  + nUtxoIn + nUtxoIn +     nZrDataEscrow   +      nDataEscrow  +      nDaoDataEscrow  + nUtxoOut;
    signal hash_inputs[n];
    // Current Value of `n` is 44 for UTXO-in = 2, UTXO-out = 2
    // log("Public-Hash-Inputs");
    // log(n);
    // --------------------- SIGNALS TO PACK ---------------------------------------------------------------------------
    // publicZAsset;                                      // 160 bit  <-- 0
    // depositAmount;                                     // 64 bit   <-- 1
    // withdrawAmount;                                    // 64 bit   ..
    // forTxReward;                                       // 40 bit   <-- 2
    // forUtxoReward;                                     // 40 bit   ..
    // forDepositReward;                                  // 40 bit   ..
    // spendTime;                                         // 32 bit   ..
    // utxoInTreeNumber[nUtxoIn];                         // 24 bit   <-- 3
    // zAccountUtxoInTreeNumber;                          // 24 bit   ..
    // utxoOutCreateTime;                                 // 32 bit   <-- 4
    // utxoOutOriginNetworkId[nUtxoOut];                  // 6 bit    ..
    // chargedAmountZkp;                                  // 32 bit   ..
    // -----------------------------------------------------------------------------------------------------------------
    // ------> 5 signals
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // NOTE: Placement inside hash_inputs & count of packed signals can't be easily changed ////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    var offset = 0;
    // [0] ---------------------------------------------------------------------------
    // publicZAsset will be packed as is
    hash_inputs[offset] <== publicZAsset;
    offset++;

    // [1] ---------------------------------------------------------------------------
    signal extAmounts[3];
    extAmounts[0] <-- depositAmount << 64;
    extAmounts[1] <-- withdrawAmount << 0;
    extAmounts[2] <-- extAmounts[1] | extAmounts[0];

    hash_inputs[offset] <== extAmounts[2];
    offset++;

    // [2] ---------------------------------------------------------------------------
    signal rewards[4];

    rewards[0] <-- forTxReward << 112;
    rewards[1] <-- forUtxoReward << 72;
    rewards[2] <-- forDepositReward << 32;
    rewards[3] <-- spendTime << 0;

    component rewardsOR = MultiOR(4);
    for (var i = 0; i < 4; i++) {
        rewardsOR.in[i] <== rewards[i];
    }

    hash_inputs[offset] <== rewardsOR.out;
    offset++;

    // [3] ---------------------------------------------------------------------------
    assert( (nUtxoIn + 1) < 10 ); // +1 for zAccountUtxoInTreeNumber, 10*24bit < 253bit !

    component utxoInTreeNumberOR = MultiOR(nUtxoIn+1);

    for (var i = 0; i < nUtxoIn; i++) {
        var local_offset = i * 24; // step is 24 bit
        utxoInTreeNumberOR.in[i] <-- utxoInTreeNumber[i] << local_offset;
    }
    utxoInTreeNumberOR.in[nUtxoIn] <-- zAccountUtxoInTreeNumber << (nUtxoIn * 24);

    hash_inputs[offset] <== utxoInTreeNumberOR.out;
    offset++;

    // [4] ---------------------------------------------------------------------------
    signal allOthers[1+nUtxoOut+1];
    allOthers[0] <-- utxoOutCreateTime << (6 * nUtxoOut + 32);

    for (var i = 1; i < nUtxoOut+1; i++) {
        var local_offset = 32 + (i - 1) * 6;
        allOthers[i] <-- utxoOutOriginNetworkId[i-1] << local_offset;
    }
    allOthers[1+nUtxoOut] <-- chargedAmountZkp << 0;

    component allOthersOR = MultiOR(1+nUtxoOut+1);

    for (var i = 0; i < 1+nUtxoOut+1; i++) {
        allOthersOR.in[i] <== allOthers[i];
    }

    hash_inputs[offset] <== allOthersOR.out;
    offset++;

    // ---------------------------------------------------------------------------------------------------------------------------
    // ---------------------- SIGNALS without PACKING ----------------------------------------------------------------------------
    // ---------------------------------------------------      // Bits ------ X,Y ---------------- only X -----------------------
    // extraInputsHash                                          // 256 bit  <-- 0                    <-- 0
    // zAssetMerkleRoot                                         // 256 bit  <-- 1                    <-- [1]        RARE CHANGE
    // utxoInMerkleRoot[nUtxoIn]                                // 256 bit  <-- nUtxoIn              <-- nUtxoIn
    // utxoInNullifier[nUtxoIn]                                 // 256 bit  <-- nUtxoIn              <-- nUtxoIn
    // zAccountUtxoInMerkleRoot                                 // 256 bit  <-- 2                    <-- 2
    // zAccountUtxoInNullifier                                  // 256 bit  <-- 3                    <-- 3
    // zAccountBlackListMerkleRoot                              // 256 bit  <-- 4                    <-- [4]        RARE CHANGE
    // zoneRecordMerkleRoot                                     // 256 bit  <-- 5                    <-- [5]        RARE CHANGE
    // zoneRecordDataEscrowEphimeralPubKey[2]                   // 256 bit  <-- 6,7                  <-- 6
    // zoneRecordDataEscrowEncryptedMessage[nZrDataEscrow][2]   // 256 bit  <-- 2 x nZrDataEscrow    <-- nZrDataEscrow
    // kytSignedMessageHash                                     // 256 bit  <-- 7                    <-- 7
    // kycKytMerkleRoot                                         // 256 bit  <-- 8                    <-- [8]        RARE CHANGE
    // dataEscrowEphimeralPubKey[2]                             // 256 bit  <-- 9,10                 <-- 9
    // dataEscrowEncryptedMessage[nDataEscrow][2]               // 256 bit  <-- 2 x nDataEscrow      <-- nDataEscrow
    // daoDataEscrowPubKey[2]                                   // 256 bit  <-- 11,12                <-- [10]       RARE CHANGE
    // daoDataEscrowEphimeralPubKey[2]                          // 256 bit  <-- 13,14                <-- 11
    // daoDataEscrowEncryptedMessage[nDaoDataEscrow][2]         // 256 bit  <-- 2 x nDaoDataEscrow   <-- nDaoDataEscrow
    // utxoOutCommitments[nUtxoOut]                             // 256 bit  <-- nUtxoOut             <-- nUtxoOut
    // zAccountUtxoOutCommitment                                // 256 bit  <-- 15                   <-- 12
    // ---------------------------------------------------------------------------------------------------------------------------
    // -x,y----------> 16     + nUtxoIn + nUtxoIn + 2 x nZrDataEscrow + 2 x nDataEscrow + 2 x nDaoDataEscrow + nUtxoOut ----------
    // -only-x-------> 8 +  5 + nUtxoIn + nUtxoIn +     nZrDataEscrow +     nDataEscrow +     nDaoDataEscrow + nUtxoOut ----------
    // -rare-inputs--> 5 ---------------------------------------------------------------------------------------------------------
    // ---------------------------------------------------------------------------------------------------------------------------
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // NOTE: Order & Count of RARE can't be changed since otherwise can't be easily cached inside smart-contracts ////////////////
    // Offset & Number of rares are very dependent ///////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [5] ---------------------------------------------------------------------------
    hash_inputs[offset] <== zAssetMerkleRoot; // [0] - RARE
    offset++;

    // [6] ---------------------------------------------------------------------------
    hash_inputs[offset] <== zAccountBlackListMerkleRoot; // [1] - RARE
    offset++;

    // [7] ---------------------------------------------------------------------------
    hash_inputs[offset] <== zoneRecordMerkleRoot; // [2] - RARE
    offset++;

    // [8] ---------------------------------------------------------------------------
    hash_inputs[offset] <== kycKytMerkleRoot; // [3] - RARE
    offset++;

    // [9] ---------------------------------------------------------------------------
    for (var i = 0; i < 1; i++) {
        hash_inputs[offset+i] <== daoDataEscrowPubKey[i]; // [4] - RARE
    }
    offset++;

    // [10] ---------------------------------------------------------------------------
    hash_inputs[offset] <== extraInputsHash;
    offset++;

    // [nUtxoIn] ----------------------------------------------------------------------
    for (var i = 0; i < nUtxoIn; i++) {
        hash_inputs[offset+i] <== utxoInMerkleRoot[i];
    }
    offset += nUtxoIn;

    // [nUtxoIn] ----------------------------------------------------------------------
    for (var i = 0; i < nUtxoIn; i++) {
        hash_inputs[offset+i] <== utxoInNullifier[i];
    }
    offset += nUtxoIn;

    // [11] ----------------------------------------------------------------------------
    hash_inputs[offset] <== zAccountUtxoInMerkleRoot;
    offset++;

    // [12] ----------------------------------------------------------------------------
    hash_inputs[offset] <== zAccountUtxoInNullifier;
    offset++;

    // [13] ----------------------------------------------------------------------------
    for (var i = 0; i < 1; i++) {
        hash_inputs[offset] <== zoneRecordDataEscrowEphimeralPubKey[i];
    }
    offset++;

    // [nZrDataEscrow] -----------------------------------------------------------------
    for (var i = 0; i < nZrDataEscrow; i++) {
        //hash_inputs[offset+2*i] <== zoneRecordDataEscrowEncryptedMessage[i][0];
        //hash_inputs[offset+2*i+1] <== zoneRecordDataEscrowEncryptedMessage[i][1];
        hash_inputs[offset+i] <== zoneRecordDataEscrowEncryptedMessage[i][0];
    }
    //offset += (2 * nZrDataEscrow);
    offset += (nZrDataEscrow);

    // [14] ----------------------------------------------------------------------------
    hash_inputs[offset] <== kytSignedMessageHash;
    offset++;

    // [15] ----------------------------------------------------------------------------
    for (var i = 0; i < 1; i++) {
        hash_inputs[offset+i] <== dataEscrowEphimeralPubKey[i];
    }
    offset++;

    // [nDataEscrow] -------------------------------------------------------------------
    for (var i = 0; i < nDataEscrow; i++) {
        //hash_inputs[offset+2*i] <== dataEscrowEncryptedMessage[i][0];
        //hash_inputs[offset+2*i+1] <== dataEscrowEncryptedMessage[i][1];
        hash_inputs[offset+i] <== dataEscrowEncryptedMessage[i][0];
    }
    //offset += (2 * nDataEscrow);
    offset += (nDataEscrow);

    // [16] ----------------------------------------------------------------------------
    for (var i = 0; i < 1; i++) {
        hash_inputs[offset+i] <== daoDataEscrowEphimeralPubKey[i];
    }
    offset++;

    // [nDaoDataEscrow] ----------------------------------------------------------------
    for (var i = 0; i < nDaoDataEscrow; i++) {
        //hash_inputs[offset+2*i] <== daoDataEscrowEncryptedMessage[i][0];
        //hash_inputs[offset+2*i+1] <== daoDataEscrowEncryptedMessage[i][1];
        hash_inputs[offset+i] <== daoDataEscrowEncryptedMessage[i][0];
    }
    //offset += (2 * nDaoDataEscrow);
    offset += (nDaoDataEscrow);

    // [17]  ----------------------------------------------------------------------------
    for (var i = 0; i < nUtxoOut; i++) {
        hash_inputs[offset+i] <== utxoOutCommitments[i];
    }
    offset += nUtxoOut;

    // [18] -----------------------------------------------------------------------------
    hash_inputs[offset] <== zAccountUtxoOutCommitment;
    offset++;

    assert(n == offset);
    ///////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POSEIDON ///////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    component multiPoseidon = MultiPoseidon(n);
    for (var i = 0; i < n; i++) {
        multiPoseidon.inputs[i] <== hash_inputs[i];
    }

    out <== multiPoseidon.out;
}
