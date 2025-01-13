//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../circuits/templates/dataEscrowElGamalEncryption.circom";
include "../../circuits/templates/utils.circom";

template DataEscrowSerializerTop ( nUtxoIn,nUtxoOut,UtxoMerkleTreeDepth ) {

    signal input zAsset;                                            // 64 bit
    signal input zAccountId;                                        // 24 bit
    signal input zAccountZoneId;                                    // 16 bit
    signal input zAccountNonce;                                     // 32 bit
    signal input utxoInMerkleTreeSelector[nUtxoIn][2];              // 2 bits: `00` - Taxi, `01` - Bus, `10` - Ferry
    signal input utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth];   // Max 32 bit
    signal input utxoInAmount[nUtxoIn];                             // 64 bit
    signal input utxoOutAmount[nUtxoOut];                           // 64 bit
    signal input utxoInOriginZoneId[nUtxoIn];                       // 16 bit
    signal input utxoOutTargetZoneId[nUtxoOut];                     // 16 bit

    signal output out[DataEscrowScalarSize_Fn(nUtxoIn, nUtxoOut,UtxoMerkleTreeDepth)];


    var ACTIVE = Active();
    var IGNORE_CONSTANT = NonActive();
    var IGNORE_ANCHORED = NonActive();
    var zAssetArraySize = ZAssetArraySize( 0 );

    signal rc_zAsset <== Uint64Tag(IGNORE_ANCHORED)(zAsset);
    signal rc_zAccountId <== Uint24Tag(ACTIVE)(zAccountId);
    signal rc_zAccountZoneId <== Uint16Tag(ACTIVE)(zAccountZoneId);
    signal rc_zAccountNonce <== Uint32Tag(ACTIVE)(zAccountNonce);
    signal rc_utxoInMerkleTreeSelector[nUtxoIn][2] <== BinaryTag2DimArray(ACTIVE,nUtxoIn,2)(utxoInMerkleTreeSelector);
    signal rc_utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth] <== BinaryTag2DimArray(ACTIVE,nUtxoIn,UtxoMerkleTreeDepth)(utxoInPathIndices);
    signal rc_utxoInOriginZoneId[nUtxoIn] <== Uint16TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInOriginZoneId);
    signal rc_utxoOutTargetZoneId[nUtxoOut] <== Uint16TagArray(IGNORE_ANCHORED,nUtxoOut)(utxoOutTargetZoneId);
    signal rc_utxoInAmount[nUtxoIn] <== Uint64TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInAmount);
    signal rc_utxoOutAmount[nUtxoOut] <== Uint64TagArray(IGNORE_ANCHORED,nUtxoOut)(utxoOutAmount);

    component dataEscrowSerializer = DataEscrowSerializer(nUtxoIn,nUtxoOut,UtxoMerkleTreeDepth);
    dataEscrowSerializer.zAsset <== rc_zAsset;
    dataEscrowSerializer.zAccountId <== rc_zAccountId;
    dataEscrowSerializer.zAccountZoneId <== rc_zAccountZoneId;
    dataEscrowSerializer.zAccountNonce <== rc_zAccountNonce;
    dataEscrowSerializer.utxoInMerkleTreeSelector <== rc_utxoInMerkleTreeSelector;
    dataEscrowSerializer.utxoInPathIndices <== rc_utxoInPathIndices;
    dataEscrowSerializer.utxoInAmount <== rc_utxoInAmount;
    dataEscrowSerializer.utxoOutAmount <== rc_utxoOutAmount;
    dataEscrowSerializer.utxoInOriginZoneId <== rc_utxoInOriginZoneId;
    dataEscrowSerializer.utxoOutTargetZoneId <== rc_utxoOutTargetZoneId;
}
