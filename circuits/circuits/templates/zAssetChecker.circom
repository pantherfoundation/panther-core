//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

/*
This template checks for the pre-requisite equalities for all types of transactions.

@input signals -
1. token - external token address
2. tokenId - tokenId associated with the token
3. zAssetId - ID generated for adding a ZAsset to ZAsset Registry
4. zAssetToken - tokenId associated with the ZAsset
5. zAssetOffset - specific number of bits
6. depositAmount - external amount for deposit
7. withdrawAmount - external amount for withdrawal
8. utxoZAssetId - zAssetId associated with the UTXO

@output signal -
1. isZkpToken - 1 if ZAsset is ZKP, 0 otherwise
*/
template ZAssetChecker() {
    signal input token;               // 160 bit - public value
    signal input tokenId;             // 256 bit - public value
    signal input zAssetId;            // 64 bit  - zAsset-Leaf
    signal input zAssetToken;         // 160 bit - zAsset-Leaf
    signal input zAssetTokenId;       // 256 bit - zAsset-Leaf
    signal input zAssetOffset;        // 6 bit   - zAsset-Leaf
    signal input depositAmount;       // 256 bit - public value
    signal input withdrawAmount;      // 256 bit - public value
    signal input utxoZAssetId;        // 64 bit  - UTXO in & out preimage value
    signal output isZkpToken;         // 1 bit -- 0-FALSE, 1-TRUE

    assert(depositAmount < 2**250);
    assert(withdrawAmount < 2**250);

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

    // [0.5] - token == 0 for internal tx
    component isTokenEqualToZeroForInternalTx = ForceEqualIfEnabled();
    isTokenEqualToZeroForInternalTx.in[0] <== 0;
    isTokenEqualToZeroForInternalTx.in[1] <== token;
    isTokenEqualToZeroForInternalTx.enabled <== enable_If_ExternalAmountsAre_Zero;

    // [1] - zAsset::ID == UTXO:zAssetID with respect to offset
    component isZAssetIdEqualToUtxoZAssetId = IsZAssetIdEqualToUtxoZAssetId();
    isZAssetIdEqualToUtxoZAssetId.zAssetId <== zAssetId;
    isZAssetIdEqualToUtxoZAssetId.utxoZAssetId <== utxoZAssetId;
    isZAssetIdEqualToUtxoZAssetId.offset <== zAssetOffset;
    isZAssetIdEqualToUtxoZAssetId.enabled <== 1; // always anabled

    // [2] - zAsset::tokenId == tokenId with respect to offset
    component isZAssetIdEqualToTokenId = IsZAssetTokenIdEqualToTokenId();
    isZAssetIdEqualToTokenId.zAssetTokenId <== zAssetTokenId;
    isZAssetIdEqualToTokenId.tokenId <== tokenId;
    isZAssetIdEqualToTokenId.offset <== zAssetOffset;
    isZAssetIdEqualToTokenId.enabled <== enable_If_ExternalAmountsAre_NOT_Zero * enable_If_zAssetOffsetAre_NOT_Zero;

    // [3] - UTXO::tokenId == tokenId with respect to offset
    component isUtxoTokenIdEqualToTokenId = IsUtxoTokenIdEqualToTokenId();
    isUtxoTokenIdEqualToTokenId.utxoZAssetId <== utxoZAssetId;
    isUtxoTokenIdEqualToTokenId.tokenId <== tokenId;
    isUtxoTokenIdEqualToTokenId.offset <== zAssetOffset;
    isUtxoTokenIdEqualToTokenId.enabled <== enable_If_ExternalAmountsAre_NOT_Zero;

    // [3.5] - tokenId == 0 for internal tx
    component isTokenIdEqualToZeroForInternalTx = ForceEqualIfEnabled();
    isTokenIdEqualToZeroForInternalTx.in[0] <== 0;
    isTokenIdEqualToZeroForInternalTx.in[1] <== tokenId;
    isTokenIdEqualToZeroForInternalTx.enabled <== enable_If_ExternalAmountsAre_Zero;

    // NOTE: zZKP zAssetID is alwase zero
    var zZKP = 0;

    component isZkpTokenEqual = IsEqual();
    isZkpTokenEqual.in[0] <== zAssetId;
    isZkpTokenEqual.in[1] <== zZKP;

    isZkpToken <== isZkpTokenEqual.out;
}

/*
Checks 'zAssetId' is equal to the 'utxoZAssetId' with respect to the 'offset'

This will be checked for the following transactions -
    1. Deposit Transaction
    2. Withdraw Transaction
    3. Internal transfer of ZAssets

with respect to offset - `offset` address the LSB bit number
for example offset = 32 means: zAsset[63:32] == utxoZAsset[63:32]
and LSBs [31:0] or LSBs[offset-1:0] are not involved in equality check
offset = 0 means: zAsset[63:0] == utxoZAsset[63:0]
tokenId is LSBs
*/
template IsZAssetIdEqualToUtxoZAssetId() {
    signal input zAssetId;
    signal input utxoZAssetId;
    signal input offset;
    signal input enabled;

    assert(zAssetId < 2**64);
    assert(offset < 33);
    assert(utxoZAssetId < 2**64);

    component n2b_zAsset = Num2Bits(64);
    n2b_zAsset.in <== zAssetId;

    component n2b_utxoZAsset = Num2Bits(64);
    n2b_utxoZAsset.in <== utxoZAssetId;

    component isEqual[64];
    component lessThen[64];
    for(var i = 0; i < 64; i++) {
        lessThen[i] = LessThan(32);
        lessThen[i].in[0] <== i;
        lessThen[i].in[1] <== offset;

        isEqual[i] = ForceEqualIfEnabled();
        isEqual[i].in[0] <== n2b_zAsset.out[i];
        isEqual[i].in[1] <== n2b_utxoZAsset.out[i];
        // if i < offset --> check is disabled
        isEqual[i].enabled <== enabled * ( 1 - lessThen[i].out );
    }
}

/*
Checks 'tokenId' is equal to the 'zAssetTokenId' with respect to the 'offset'

This will be checked for the following transactions -
    1. Deposit Transaction
    2. Withdraw Transaction
*/
template IsZAssetTokenIdEqualToTokenId() {
    signal input zAssetTokenId;
    signal input tokenId;
    signal input offset;
    signal input enabled;

    assert(zAssetTokenId < 2**254);
    assert(tokenId < 2**254);
    assert(offset < 33);

    component n2b_tokenId = Num2Bits(254);
    n2b_tokenId.in <== tokenId;

    component n2b_zAssetTokenId = Num2Bits(254);
    n2b_zAssetTokenId.in <== zAssetTokenId;

    component isEqual[254];
    component lessThen[254];
    for(var i = 0; i < 254; i++) {
        lessThen[i] = LessThan(32);
        lessThen[i].in[0] <== i;
        lessThen[i].in[1] <== offset;

        isEqual[i] = ForceEqualIfEnabled();
        isEqual[i].in[0] <== n2b_tokenId.out[i];
        isEqual[i].in[1] <== n2b_zAssetTokenId.out[i];
        // if i < offset --> check is disabled
        isEqual[i].enabled <== enabled * ( 1 - lessThen[i].out );
    }
}

/*
Checks 'tokenId' is equal to the 'utxoZAssetId' with respect to the 'offset'

This will be checked for the following transactions -
    1. Deposit Transaction
    2. Withdraw Transaction

// lsb_mask = 2^offset - 1
// utxoZAssetId & lsb_mask === tokenId & lsb_mask
*/
template IsUtxoTokenIdEqualToTokenId() {
    signal input utxoZAssetId;
    signal input tokenId;
    signal input offset;
    signal input enabled;

    assert(utxoZAssetId < 2**64);
    assert(tokenId < 2**254);
    assert(offset < 33);

    component n2b_utxoZAssetId = Num2Bits(254);
    n2b_utxoZAssetId.in <== utxoZAssetId;

    component n2b_tokenId = Num2Bits(254);
    n2b_tokenId.in <== tokenId;

    component isEqual[64];
    component lessThen[64];
    for(var i = 0; i < 64; i++) {
        lessThen[i] = LessThan(32);
        lessThen[i].in[0] <== i;
        lessThen[i].in[1] <== offset;

        isEqual[i] = ForceEqualIfEnabled();
        isEqual[i].in[0] <== n2b_utxoZAssetId.out[i];
        isEqual[i].in[1] <== n2b_tokenId.out[i];
        // if i < offset --> check is enabled
        isEqual[i].enabled <== enabled * ( lessThen[i].out );
    }
}
