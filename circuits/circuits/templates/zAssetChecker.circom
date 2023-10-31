//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

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
    isZAssetIdEqualToUtxoZAssetId.enabled <== 1; // always anabled

    // [2] - zAsset::tokenId == tokenId with respect to offset
    component isZAssetIdEqualToTokenId = IsZAssetTokenIdEqualToTokenId();
    isZAssetIdEqualToTokenId.zAssetTokenId <== zAssetTokenId;
    isZAssetIdEqualToTokenId.tokenId <== tokenId;
    isZAssetIdEqualToTokenId.offset <== zAssetOffset;
    isZAssetIdEqualToTokenId.enabled <== enable_If_ExternalAmountsAre_NOT_Zero;

    // [3] - UTXO::tokenId == tokenId with respect to offset
    component isUtxoTokenIdEqualToTokenId = IsUtxoTokenIdEqualToTokenId();
    isUtxoTokenIdEqualToTokenId.utxoZAssetId <== utxoZAssetId;
    isUtxoTokenIdEqualToTokenId.tokenId <== tokenId;
    isUtxoTokenIdEqualToTokenId.offset <== zAssetOffset;
    isUtxoTokenIdEqualToTokenId.enabled <== enable_If_ExternalAmountsAre_NOT_Zero;

    // NOTE: zZKP zAssetID is alwase zero
    var zZKP = 0;

    component isZkpTokenEqual = IsEqual();
    isZkpTokenEqual.in[0] <== zAssetId;
    isZkpTokenEqual.in[1] <== zZKP;

    isZkpToken <== isZkpTokenEqual.out;
}

// with respect to offset - `offset` address the LSB bit number
// for example offset = 32 means: zAsset[63:32] == utxoZAsset[63:32]
// and LSBs [31:0] or LSBs[offset-1:0] are not involved in equality check
// offset = 0 means: zAsset[63:0] == utxoZAsset[63:0]
// tokenId is LSBs
template IsZAssetIdEqualToUtxoZAssetId() {
    signal input zAssetId;
    signal input utxoZAssetId;
    signal input offset;
    signal input enabled;

    assert(zAssetId < 2**64);
    assert(offset < 33);
    assert(utxoZAssetId < 2**64);

    signal zAssetTmp;
    zAssetTmp <-- zAssetId >> offset;

    signal utxoZAssetTmp;
    utxoZAssetTmp <-- utxoZAssetId >> offset;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== zAssetTmp;
    isEqual.in[1] <== utxoZAssetTmp;
    isEqual.enabled <== enabled;
}


template IsZAssetTokenIdEqualToTokenId() {
    signal input zAssetTokenId;
    signal input tokenId;
    signal input offset;
    signal input enabled;

    assert(zAssetTokenId < 2**254);
    assert(tokenId < 2**254);
    assert(offset < 33);

    signal tokenIdTmp;
    tokenIdTmp <-- tokenId >> offset;
    signal tokenIdTmp1;
    tokenIdTmp1 <-- tokenIdTmp << offset;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== tokenIdTmp1;
    isEqual.in[1] <== zAssetTokenId;
    isEqual.enabled <== enabled;
}

template IsUtxoTokenIdEqualToTokenId() {
    signal input utxoZAssetId;
    signal input tokenId;
    signal input offset;
    signal input enabled;

    assert(utxoZAssetId < 2**64);
    assert(tokenId < 2**254);
    assert(offset < 33);

    //signal lsb_mask;
    var lsb_mask = 2**offset - 1;

    signal utxoZAssetIdTmp;
    utxoZAssetIdTmp <-- utxoZAssetId & lsb_mask;
    signal tokenIdTmp;
    tokenIdTmp <-- tokenId & lsb_mask;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== utxoZAssetIdTmp;
    isEqual.in[1] <== tokenIdTmp;
    isEqual.enabled <== enabled;
}

// the old version for reference
template ZAssetChecker2() {
    signal input token;               // 160 bit
    signal input tokenId;             // 256 bit
    signal input zAsset;              // 64 bit
    signal input zAssetToken;         // 160 bit
    signal input zAssetTokenId;       // 256 bit
    signal input zAssetOffset;        // 6 bit
    signal input depositAmount;       // 256 bit
    signal input withdrawAmount;      // 256 bit
    signal input utxoZAsset;          // 64 bit
    signal output isZkpToken;         // 1 bit -- 0-FALSE, 1-TRUE

    assert(depositAmount < 2**250);
    assert(withdrawAmount < 2**250);

    component isZeroAmounts = IsZero();
    isZeroAmounts.in <== depositAmount + withdrawAmount; // TODO: isZeroExternalAmounts

    // var isTxInternalOnly = isZeroAmounts.out;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // case-A - internal only TX - require:
    // 1) token == 0
    // 2) tokenId == 0
    // 3) If offset == 0
    // ---> 3.1) tokenId was NOT used to setup zAssetID-LSBs (tokenId < 2^32) --- ERC20 case
    // --- OR ---
    // ---> 3.2) tokenId > 2^32 and specific zAssetId is given per each tokenId --- Not standart case of ERC721/ERC1155
    //           AND zAsset::tokenId is set to tokenId
    // 4) If offset != 0
    // ---> 4.1) public tokenId < 2^32 (otherwise offset must be ZERO and specific zAsset::tokenId was used)
    // In any case of 3) or 4) still we need to check zAsset == UTXO::zAssetId
    // This check will be made with respect to zAsset::offset
    //      zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    var enableIfAmountsAre_Zero = isZeroAmounts.out;

    // 1) Enabled only if [Deposit-Amount && Withdraw-Amount] === ZERO
    component forceEqualToZeroTokenIfTxHasExternalPart = ForceEqualIfEnabled();
    forceEqualToZeroTokenIfTxHasExternalPart.in[0] <== token;
    forceEqualToZeroTokenIfTxHasExternalPart.in[1] <== 0;
    forceEqualToZeroTokenIfTxHasExternalPart.enabled <== enableIfAmountsAre_Zero;

    // 2) Enabled only if [Deposit-Amount && Withdraw-Amount] == ZERO
    component forceEqualToZeroTokenID_IfTxHasExternalPart = ForceEqualIfEnabled();
    forceEqualToZeroTokenID_IfTxHasExternalPart.in[0] <== tokenId;
    forceEqualToZeroTokenID_IfTxHasExternalPart.in[1] <== 0;
    forceEqualToZeroTokenID_IfTxHasExternalPart.enabled <== enableIfAmountsAre_Zero;

    // TODO: 3) & 4) --- zAsset == UTXO::zAssetId (with respect to zAsset::offset)

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // case-B - external & internal TX - require:
    // 1) token == zAsset::token
    // 2) If tokenId == 0 ---> ERC20 case // TODO: is it posible to have zero-token-ID ?
    //       require:
    //          2.1) zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)
    // 3) If tokenId != 0 ---> ERC721/ERC1155 case
    //    3.1) If zAsset::tokenId == 0 ---> IDs are sequential (single zAsset-Leaf allows for IDs < 2**32 & offset)
    //            require:
    //               3.1.a) tokenId == UTXO::zAssetId (with respect of LSBs & offset)
    //               3.1.b) zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)
    //    3.2) If zAsset::tokenId != 0 ---> special case of not sequential IDs
    //            require:
    //               3.2.a) tokenId == zAsset::tokenId
    //               3.2.b) zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)
    // 4) Require:
    //        4.1) If tokenId >= 2^32
    //                require:
    //                    zAsset::tokenId == tokenId
    //        4.2) If 0 < tokenId < 2^32 <------------- THIS ONE NOT NEEDED since 3) + 3.1) check
    //                require:
    //                    tokneId == UTXO::zAssetId (with respect of LSBs & offset)
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // 1) Enabled only if [Deposit-Amount || Withdraw-Amount] != ZERO
    var enableIfAmountsAre_NotZero = 1 - isZeroAmounts.out;

    component forceTokenEqualToZAssetToken = ForceEqualIfEnabled();
    forceTokenEqualToZAssetToken.in[0] <== token;
    forceTokenEqualToZAssetToken.in[1] <== zAssetToken;
    forceTokenEqualToZAssetToken.enabled <== enableIfAmountsAre_NotZero;

    // 2) If tokenId == 0 ---> ERC20 case
    component isTokenIdZero = IsZero();
    isTokenIdZero.in <== tokenId;
    // TODO: 2.1) --- zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)

    // 3) If tokenId != 0 ---> ERC721/ERC1157 case - sequential IDs < 2^32
    var enableIfTokenIdIs_NotZero = 1 - isTokenIdZero.out;

    // 3.1) If zAsset::tokenId == 0 ---> IDs are sequential (single zAsset-Leaf allows for IDs < 2**32 & offset)
    component isZAssetTokenIdZero = IsZero();
    isZAssetTokenIdZero.in <== zAssetTokenId;

    var enableIfZAssetTokenIdIs_Zero = isZAssetTokenIdZero.out;

    // 3.1.a) tokenId == UTXO::zAssetId (with respect of LSBs & offset)
    component if_3_1_a_case = IsTokenIdEqualToUtxoZAssetTokenId();
    if_3_1_a_case.tokenId <== tokenId;
    if_3_1_a_case.utxoZAsset <== utxoZAsset;
    if_3_1_a_case.offset <== zAssetOffset;

    // Enable only IF 3) & 3.1) is TRUE
    signal enable_3_1_a_case;
    enable_3_1_a_case <-- enableIfTokenIdIs_NotZero & enableIfZAssetTokenIdIs_Zero;
    if_3_1_a_case.enabled <== enable_3_1_a_case;

    // TODO: 3.1.b) --- zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)

    // 3.2) If zAsset::tokenId != 0 ---> special case of not sequential IDs or IDs >= 2^32
    var enableIfZAssetTokenIdIs_NotZero = 1 - isZAssetTokenIdZero.out;

    // 3.2.a) tokenId == zAsset::tokenId
    component if_3_2_a_case = ForceEqualIfEnabled();
    if_3_2_a_case.in[0] <== tokenId;
    if_3_2_a_case.in[1] <== zAssetTokenId;
    // Enable only IF: 3) & 3.2) is TRUE
    signal enable_3_2_a_case;
    enable_3_2_a_case <-- enableIfTokenIdIs_NotZero & enableIfZAssetTokenIdIs_NotZero;
    if_3_2_a_case.enabled <== enable_3_2_a_case;

    // TODO: 3.2.b) --- zAsset::ID == UTXO::zAssetId (with respect to zAsset::offset)

    // 4.1) If tokenId >= 2^32 require zAsset::tokenId == tokenId
    component isTokenId_greater_then_2_pow_32 = LessThan(252);
    isTokenId_greater_then_2_pow_32.in[0] <== 2**32;
    isTokenId_greater_then_2_pow_32.in[1] <== tokenId;

    component if_4_1_case = ForceEqualIfEnabled();
    if_4_1_case.in[0] <== tokenId;
    if_4_1_case.in[1] <== zAssetTokenId;
    // Enable only IF: case-b && tokenId >= 2^32
    signal enable_4_1_case;
    enable_4_1_case <-- enableIfAmountsAre_NotZero & isTokenId_greater_then_2_pow_32.out;
    if_4_1_case.enabled <== enable_4_1_case;

    // case-a: 3), 4), case-b: 2.1), 3.1.b), 3.2.b) cases
    component isZAssetEqual = IsZAssetIdEqualToUtxoZAssetId();
    isZAssetEqual.zAssetId <== zAsset;
    isZAssetEqual.offset <== zAssetOffset;
    isZAssetEqual.utxoZAssetId <== utxoZAsset;
    isZAssetEqual.enabled <== 1; // always

    // ---------------------------------------------------------------------------------------------------------------//
    // If token != 0 && tokenId < 2^32  then
    //   zAsset[31:0] === tokenId[31:0]
    // component isLessThen_tokenId_less_2_pow_32 = LessThen(252);
    // isLessThen_tokenId_less_2_pow_32.in[0] <== tokenId;
    // isLessThen_tokenId_less_2_pow_32.in[1] <== 2**32;
    // ---------------------------------------------------------------------------------------------------------------//

    // TODO: FIXME - put real zZKP token
    var zZKP = 0;

    component isZkpTokenEqual = IsEqual();
    isZkpTokenEqual.in[0] <== zAsset;
    isZkpTokenEqual.in[1] <== zZKP;

    isZkpToken <== isZkpTokenEqual.out;
}

// with respect to offset - `offset` address the LSB bit number
// for example offset = 32 means: zAsset[63:32] == utxoZAsset[63:32]
// and LSBs [31:0] or LSBs[offset-1:0] are not involved in equality check
// offset = 0 means: zAsset[63:0] == utxoZAsset[63:0]
// tokenId is LSBs
template IsTokenIdEqualToUtxoZAssetTokenId() {
    signal input tokenId;
    signal input offset;
    signal input utxoZAsset;
    signal input enabled;

    assert(offset < 33);
    assert(utxoZAsset < 2**64);

    // we want to extract offset-bits, TODO: double check 254 bits issue !!!
    // 254 is MSB in FF
    // shift-left to 254 - offset - (254 - 32) = 220
    var shift = 254 - offset;
    signal tokenIdTmp1;
    tokenIdTmp1 <-- tokenId << shift;
    signal tokenIdTmp2;
    tokenIdTmp2 <-- tokenIdTmp1 >> shift;

    signal utxoZAssetTmp1;
    utxoZAssetTmp1 <-- utxoZAsset << shift;
    signal utxoZAssetTmp2;
    utxoZAssetTmp2 <-- utxoZAssetTmp1 >> shift;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== tokenIdTmp2;
    isEqual.in[1] <== utxoZAssetTmp2;
    isEqual.enabled <== enabled;
}

