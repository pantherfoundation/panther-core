// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./utils.circom";

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

///*
// This template matches the ID of a zAsset a transaction operates with, as well as params of the
// token represented by the ZAsset, against ID and other params of the ZAsset's Batch (Leaf).
// The template is used across all transaction types.
//
// The file './zAssetNoteInclusionProver.circom' provides more comments on ZAssets, Batches, the
// ZAssetsTree and its Leafs.
//
// ZAsset's ID
// -----------
// It is an id that uniquely identifies a ZAsset.
// This ID is a parameter of every ZAsset UTXO (unlike ZAccount UTXO) which specifies the ZAsset
// a UTXO represents. Circuits treat UTXOs with distinct ZAsset ID's as UTXOs of different ZAssets.
//
// The ZAsset ID is is a 64-bit number.
// Its 32 most significant bits link the ZAsset to the ZAssetsTree Leaf/Batch the ZAsset belongs to:
// these bits in the ZAsset ID should be the same as the 32 MSBs of the Batch ID. If they are, then
// parameters of the Batch must be applied for handling the ZAsset.
// The 32 less significant bits specify the external ID of a token represented by the ZAsset:
// the 'uint' number in these bits, when added to the Batch parameter 'startTokenId', yields the
// external ID.
//
// For ERC-20 tokens, the 32 LSBs MUST be 0, and smart contracts enforce it on ZAssets registration.
//
// The ID of the ZAsset representing the ZKP token (from the Batch with ID 0), MUST be 0.
//
// In most cases, a ZAsset is supposed to be "contained" by a single Batch only. However, for tokens
// circulating on multiple supported networks, multiple Batches may contain the same ZAsset - the ID
// of a ZAsset then will match to IDs of all these Batches (parameters of a transaction will define
// then which one of these Batches must be taken into account).
//
// Examples
// - ERC-20 token from a Batch with ID of 9*2^32 will have the ZAsset's ID 9*2^32+0.
// - NFT with external token ID 56 from the Batch with ID 10*2^32, where this NFT is the only
//   token in the Batch (startTokenId = 56, offset = 0), will have the ZAsset's ID
//   10*2^32+0.
// - NFT with external token ID 173 from the Batch with ID of 11*2^32, containing 33 NFTs with
//   external IDs ranging from 167 to 199 (startTokenId = 167, offset = 32), will
//   have a the ZAsset's ID 11*2^32+6.
//
// This circuit code names the signal for ZAsset's ID as 'utxoZAssetId'.
// Other circuits name this signal as 'zAsset'.
// */

///*
// @input signals -
// 1. token - the token contract type and address, or 0 for internal transactions
//    (i.e., if both depositAmount and withdrawAmount are zero).
// 2. tokenId - token's external ID, or 0 for internal transactions.
// 3. zAssetId -  ZAsset Batch's ID (recorded in the ZAssetsTree Leaf).
// 4. zAssetToken - token contract type and address (recorded in the ZAssetsTree Leaf).
// 5. zAssetTokenId - starting value of the range for external IDs (recorded in the Leaf).
// 6. zAssetOffset - offset for the the external ID range's end value (recorded in the Leaf).
// 7. depositAmount - amount deposited in the tx.
// 8. withdrawAmount - amount withdrawn in the tx.
// 9. utxoZAssetId - ZAsset ID recorded in the transaction's UTXOs.
//
// @output signal -
// 1. isZkpToken - 1 if ZAsset represents the ZKP token (from the Batch with ID 0), 0 otherwise.
// */
template ZAssetChecker() {
    signal input {uint168} token;
    signal input {uint252} tokenId;
    signal input {uint64}  zAssetId;
    signal input {uint168} zAssetToken;
    signal input {uint252} zAssetTokenId;
    signal input {uint32}  zAssetOffset;
    signal input {uint96}  depositAmount;
    signal input {uint96}  withdrawAmount;
    signal input {uint64}  utxoZAssetId;
    signal output {binary} isZkpToken;

    var ACTIVE = Active();
    var NON_ACTIVE = NonActive();

    assert(depositAmount < 2**96);
    assert(withdrawAmount < 2**96);

    component isZeroExternalAmounts = IsZero();
    isZeroExternalAmounts.in <== depositAmount + withdrawAmount;
    var isInternalTx = isZeroExternalAmounts.out;
    var isNotInternalTx = 1 - isZeroExternalAmounts.out;

    // [0] - if NOT internal tx, force `zAssetToken == token`
    component isZAssetTokenEqualToToken = ForceEqualIfEnabled();
    isZAssetTokenEqualToToken.in[0] <== zAssetToken;
    isZAssetTokenEqualToToken.in[1] <== token;
    isZAssetTokenEqualToToken.enabled <== isNotInternalTx;

    // [1] - force `zAssetId[63:32] == utxoZAssetId[63:32]`
    component isZAssetIdEqualToUtxoZAssetId = IsZAssetIdEqualToUtxoZAssetId();
    isZAssetIdEqualToUtxoZAssetId.zAssetId <== zAssetId;
    isZAssetIdEqualToUtxoZAssetId.utxoZAssetId <== utxoZAssetId;
    isZAssetIdEqualToUtxoZAssetId.nMSBs <== Uint6Tag(NON_ACTIVE)(32);
    isZAssetIdEqualToUtxoZAssetId.enabled <== BinaryOne()(); // always enabled

    // [2] - if NOT internal tx, force `zAssetTokenId ≤ tokenId ≤ zAssetTokenId+zAssetOffset`
    component isZAssetIdEqualToTokenId = IsTokenIdInZAssetTokenIdRange();
    isZAssetIdEqualToTokenId.zAssetTokenId <== zAssetTokenId;
    isZAssetIdEqualToTokenId.tokenId <== tokenId;
    isZAssetIdEqualToTokenId.offset <== zAssetOffset;
    isZAssetIdEqualToTokenId.enabled <== BinaryTag(ACTIVE)(isNotInternalTx);

    // [3] - if NOT internal tx, force `tokenId == zAssetTokenId + uint(utxoZAssetId[31..0])`
    signal tokenIdDiff <== Uint252Tag(ACTIVE)(tokenId - zAssetTokenId);

    component isUtxoTokenIdEqualToTokenId = IsUtxoTokenIdEqualToTokenId();
    isUtxoTokenIdEqualToTokenId.utxoZAssetId <== utxoZAssetId;
    isUtxoTokenIdEqualToTokenId.tokenId <== tokenIdDiff;
    isUtxoTokenIdEqualToTokenId.nLSBs <== Uint6Tag(NON_ACTIVE)(32);
    isUtxoTokenIdEqualToTokenId.enabled <== BinaryTag(ACTIVE)(isNotInternalTx);

    // [4] - if internal tx, force `token == 0`
    component isTokenEqualToZeroForInternalTx = ForceEqualIfEnabled();
    isTokenEqualToZeroForInternalTx.in[0] <== 0;
    isTokenEqualToZeroForInternalTx.in[1] <== token;
    isTokenEqualToZeroForInternalTx.enabled <== isInternalTx;

    // [5] - if internal tx, force `tokenId == 0`
    component isTokenIdEqualToZeroForInternalTx = ForceEqualIfEnabled();
    isTokenIdEqualToZeroForInternalTx.in[0] <== 0;
    isTokenIdEqualToZeroForInternalTx.in[1] <== tokenId;
    isTokenIdEqualToZeroForInternalTx.enabled <== BinaryTag(ACTIVE)(isInternalTx);

    // NOTE: zZKP zAssetID is always zero
    var zZKP = ZkpToken();

    component isZkpTokenEqual = IsEqual();
    isZkpTokenEqual.in[0] <== zAssetId;
    isZkpTokenEqual.in[1] <== zZKP;

    isZkpToken <== isZkpTokenEqual.out;
}

// If enabled, checks 'nMSBs' number of MSBs in 'zAssetId' and 'utxoZAssetId' are the same
// Examples:
// nMSBs = 32: zAsset[63:32] == utxoZAsset[63:32], bits [31:0] (31=nMSBs-1) are ignored.
// nMSBs = 0: zAsset[63:0] == utxoZAsset[63:0]
template IsZAssetIdEqualToUtxoZAssetId() {
    signal input {uint64} zAssetId;
    signal input {uint64} utxoZAssetId;
    signal input {uint6}  nMSBs;
    signal input {binary} enabled;

    var isLSB = 1;
    var isMSB = 1 - isLSB;

    component p = IsIdEqualToId(64,64,isMSB);
    p.id[0] <== zAssetId;       // 64
    p.id[1] <== utxoZAssetId;   // 64
    p.nBits <== nMSBs;
    p.enabled <== enabled;
}

// If enabled, checks 'tokenId' is in the range '[zAssetTokenId .. zAssetTokenId + offset]'
template IsTokenIdInZAssetTokenIdRange() {
    signal input {uint252} zAssetTokenId;
    signal input {uint252} tokenId;
    signal input {uint32}  offset;
    signal input {binary}  enabled;

    component p = RangeCheck(252);
    p.lowerBound <== zAssetTokenId;
    p.in <== tokenId;
    p.upperBound <== zAssetTokenId + offset;
    p.enabled <== enabled;
}

// If enabled, checks 'nLSBs' number of LSBs in 'tokenId' and 'utxoZAssetId' are the same
// Examples:
// nLSBs = 32: tokenId[31:0] == utxoZAsset[31:0], bits [63:32] are ignored.
template IsUtxoTokenIdEqualToTokenId() {
    signal input {uint64}  utxoZAssetId;
    signal input {uint252} tokenId;
    signal input {uint6}   nLSBs;
    signal input {binary}  enabled;

    var isLSB = 1;
    component p = IsIdEqualToId(64,252,isLSB);
    p.id[0] <== utxoZAssetId; // 64
    p.id[1] <== tokenId;      // 252
    p.nBits <== nLSBs;
    p.enabled <== enabled;
}

// - IF isLSB == TRUE:
// - THEN: id[0][nBits..0]   == id[1][nBits..0]
// - ELSE: id[0][MSB..nBits] == id[1][MSB..nBits]
// - nBits - 0..32
template IsIdEqualToId(N,M,isLSB) {
    signal input           id[2];
    signal input {uint6}   nBits;
    signal input {binary}  enabled;

    assert(N < 254);
    assert(M < 254);
    assert(id[0] < 2**N);
    assert(id[1] < 2**M);
    assert(N <= M);
    assert(0 <= nBits <= 32);
    assert(0 <= isLSB <= 1);

    component n2b_0;
    n2b_0 = Num2Bits(N);
    n2b_0.in <== id[0];

    component n2b_1;
    n2b_1 = Num2Bits(M);
    n2b_1.in <== id[1];

    component isEqual[N];
    component lessThen[N];
    for(var i = 0; i < N; i++) {
        lessThen[i] = LessThan(32);
        lessThen[i].in[0] <== i;
        lessThen[i].in[1] <== nBits;

        isEqual[i] = ForceEqualIfEnabled();
        isEqual[i].in[0] <== n2b_0.out[i];
        isEqual[i].in[1] <== n2b_1.out[i];
        if( isLSB ) {
            // if i < nBits --> check is enabled
            // i = 32, nBits = 32: i < 32 --> lessThen[i].out = 0
            isEqual[i].enabled <== enabled * ( lessThen[i].out );
        } else {
            // if i >= nBits --> check is enabled
            // i = 32, nBits = 32: i < 32 --> ( 1 - lessThen[i].out ) = 1
            isEqual[i].enabled <== enabled * ( 1 - lessThen[i].out );
        }
    }
}
