//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./utils.circom";

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

///*
// This template checks for the pre-requisite equalities for all types of transactions.
//
// @input signals -
// 1. token - external token address
// 2. tokenId - tokenId associated with the token
// 3. zAssetId - ID generated for adding a ZAsset to ZAsset Registry
// 4. zAssetToken - tokenId associated with the ZAsset
// 5. zAssetOffset - specific number of bits
// 6. depositAmount - external amount for deposit
// 7. withdrawAmount - external amount for withdrawal
// 8. utxoZAssetId - zAssetId associated with the UTXO
//
// @output signal -
// 1. isZkpToken - 1 if ZAsset is ZKP, 0 otherwise
// */
template ZAssetChecker() {
    signal input {uint168} token;
    signal input {uint252} tokenId;
    signal input {uint64}  zAssetId;
    signal input {uint168} zAssetToken;
    signal input {uint252} zAssetTokenId;
    signal input {uint6}   zAssetOffset;
    signal input {uint96}  depositAmount;
    signal input {uint96}  withdrawAmount;
    signal input {uint64}  utxoZAssetId;
    signal output {binary} isZkpToken;

    var ACTIVE = Active();
    assert(depositAmount < 2**96);
    assert(withdrawAmount < 2**96);

    component isZeroExternalAmounts = IsZero();
    isZeroExternalAmounts.in <== depositAmount + withdrawAmount;
    var enable_If_ExternalAmountsAre_Zero = isZeroExternalAmounts.out;
    var enable_If_ExternalAmountsAre_NOT_Zero = 1 - isZeroExternalAmounts.out;

    component isZeroOffset = IsZero();
    isZeroOffset.in <== zAssetOffset;
    var enable_If_zAssetOffsetAre_NOT_Zero = 1 - isZeroOffset.out;

    // [0] - zAsset::token == token
    component isZAssetTokenEqualToToken = ForceEqualIfEnabled();
    isZAssetTokenEqualToToken.in[0] <== zAssetToken;
    isZAssetTokenEqualToToken.in[1] <== token;
    isZAssetTokenEqualToToken.enabled <== enable_If_ExternalAmountsAre_NOT_Zero;

    // [1] - zAsset::ID == UTXO:zAssetID with respect to offset
    component isZAssetIdEqualToUtxoZAssetId = IsZAssetIdEqualToUtxoZAssetId();
    isZAssetIdEqualToUtxoZAssetId.zAssetId <== zAssetId;
    isZAssetIdEqualToUtxoZAssetId.utxoZAssetId <== utxoZAssetId;
    isZAssetIdEqualToUtxoZAssetId.offset <== zAssetOffset;
    isZAssetIdEqualToUtxoZAssetId.enabled <== BinaryOne()(); // always enabled

    // [2] - zAsset::tokenId == tokenId with respect to offset
    component isZAssetIdEqualToTokenId = IsZAssetTokenIdEqualToTokenId();
    isZAssetIdEqualToTokenId.zAssetTokenId <== zAssetTokenId;
    isZAssetIdEqualToTokenId.tokenId <== tokenId;
    isZAssetIdEqualToTokenId.offset <== zAssetOffset;
    isZAssetIdEqualToTokenId.enabled <== BinaryTag(ACTIVE)(enable_If_ExternalAmountsAre_NOT_Zero * enable_If_zAssetOffsetAre_NOT_Zero);

    // [3] - UTXO::tokenId == tokenId with respect to offset
    component isUtxoTokenIdEqualToTokenId = IsUtxoTokenIdEqualToTokenId();
    isUtxoTokenIdEqualToTokenId.utxoZAssetId <== utxoZAssetId;
    isUtxoTokenIdEqualToTokenId.tokenId <== tokenId;
    isUtxoTokenIdEqualToTokenId.offset <== zAssetOffset;
    isUtxoTokenIdEqualToTokenId.enabled <== BinaryTag(ACTIVE)(enable_If_ExternalAmountsAre_NOT_Zero);

    // [4] - token == 0 for internal tx
    component isTokenEqualToZeroForInternalTx = ForceEqualIfEnabled();
    isTokenEqualToZeroForInternalTx.in[0] <== 0;
    isTokenEqualToZeroForInternalTx.in[1] <== token;
    isTokenEqualToZeroForInternalTx.enabled <== enable_If_ExternalAmountsAre_Zero;

    // [5] - tokenId == 0 for internal tx
    component isTokenIdEqualToZeroForInternalTx = ForceEqualIfEnabled();
    isTokenIdEqualToZeroForInternalTx.in[0] <== 0;
    isTokenIdEqualToZeroForInternalTx.in[1] <== tokenId;
    isTokenIdEqualToZeroForInternalTx.enabled <== BinaryTag(ACTIVE)(enable_If_ExternalAmountsAre_Zero);

    // NOTE: zZKP zAssetID is always zero
    var zZKP = ZkpToken();

    component isZkpTokenEqual = IsEqual();
    isZkpTokenEqual.in[0] <== zAssetId;
    isZkpTokenEqual.in[1] <== zZKP;

    isZkpToken <== isZkpTokenEqual.out;
}

// /*
// Checks 'zAssetId' is equal to the 'utxoZAssetId' with respect to the 'offset'
//
// This will be checked for the following transactions -
//    1. Deposit Transaction
//    2. Withdraw Transaction
//    3. Internal transfer of ZAssets
//
// with respect to offset - `offset` address the LSB bit number
// for example offset = 32 means: zAsset[63:32] == utxoZAsset[63:32]
// and LSBs [31:0] or LSBs[offset-1:0] are not involved in equality check
// offset = 0 means: zAsset[63:0] == utxoZAsset[63:0]
// tokenId is LSBs
// */
template IsZAssetIdEqualToUtxoZAssetId() {
    signal input {uint64} zAssetId;
    signal input {uint64} utxoZAssetId;
    signal input {uint6}  offset;
    signal input {binary} enabled;

    var isLSB = 1;
    var isMSB = 1 - isLSB;

    component p = IsIdEqualToId(64,64,isMSB);
    p.id[0] <== zAssetId;       // 64
    p.id[1] <== utxoZAssetId;   // 64
    p.offset <== offset;
    p.enabled <== enabled;
}

// /*
// Checks 'tokenId' is equal to the 'zAssetTokenId' with respect to the 'offset'
//
// This will be checked for the following transactions -
//     1. Deposit Transaction
//     2. Withdraw Transaction
// */
template IsZAssetTokenIdEqualToTokenId() {
    signal input {uint252} zAssetTokenId;
    signal input {uint252} tokenId;
    signal input {uint6}   offset;
    signal input {binary}  enabled;

    var isLSB = 1;
    var isMSB = 1 - isLSB;

    component p = IsIdEqualToId(252,252,isMSB);
    p.id[0] <== zAssetTokenId; // 252
    p.id[1] <== tokenId;       // 252
    p.offset <== offset;
    p.enabled <== enabled;
}

// /*
// Checks 'tokenId' is equal to the 'utxoZAssetId' with respect to the 'offset'
//
// This will be checked for the following transactions -
//     1. Deposit Transaction
//     2. Withdraw Transaction
//
// // lsb_mask = 2^offset - 1
// // utxoZAssetId & lsb_mask === tokenId & lsb_mask
// */
template IsUtxoTokenIdEqualToTokenId() {
    signal input {uint64}  utxoZAssetId;
    signal input {uint252} tokenId;
    signal input {uint6}   offset;
    signal input {binary}  enabled;

    var isLSB = 1;
    component p = IsIdEqualToId(64,252,isLSB);
    p.id[0] <== utxoZAssetId; // 64
    p.id[1] <== tokenId;      // 252
    p.offset <== offset;
    p.enabled <== enabled;
}

// - IF isLSB == TRUE:
// - THEN: id[0][offset..0]   == id[1][offset..0]
// - ELSE: id[0][MSB..offset] == id[1][MSB..offset]
// - offset - 0..32
template IsIdEqualToId(N,M,isLSB) {
    signal input           id[2];
    signal input {uint6}   offset;
    signal input {binary}  enabled;

    assert(N < 254);
    assert(M < 254);
    assert(id[0] < 2**N);
    assert(id[1] < 2**M);
    assert(N <= M);
    assert(0 <= offset <= 32);
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
        lessThen[i].in[1] <== offset;

        isEqual[i] = ForceEqualIfEnabled();
        isEqual[i].in[0] <== n2b_0.out[i];
        isEqual[i].in[1] <== n2b_1.out[i];
        if( isLSB ) {
            // if i < offset --> check is enabled
            // i = 32, offset = 32: i < 32 --> lessThen[i].out = 0
            isEqual[i].enabled <== enabled * ( lessThen[i].out );
        } else {
            // if i >= offset --> check is enabled
            // i = 32, offset = 32: i < 32 --> ( 1 - lessThen[i].out ) = 1
            isEqual[i].enabled <== enabled * ( 1 - lessThen[i].out );
        }
    }
}
