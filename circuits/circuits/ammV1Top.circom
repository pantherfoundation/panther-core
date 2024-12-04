//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./ammV1.circom";
include "./templates/utils.circom";

template AmmV1Top ( UtxoLeftMerkleTreeDepth,
                    UtxoMiddleMerkleTreeDepth,
                    ZNetworkMerkleTreeDepth,
                    ZAssetMerkleTreeDepth,
                    ZAccountBlackListMerkleTreeDepth,
                    ZZoneMerkleTreeDepth ) {
    //////////////////////////////////////////////////////////////////////////////////////////////
    // Ferry MT size
    var UtxoRightMerkleTreeDepth = UtxoRightMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // Equal to ferry MT size
    var UtxoMerkleTreeDepth = UtxoMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // Bus MT extra levels
    var UtxoMiddleExtraLevels = UtxoMiddleExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, UtxoLeftMerkleTreeDepth);
    // Ferry MT extra levels
    var UtxoRightExtraLevels = UtxoRightExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    //////////////////////////////////////////////////////////////////////////////////////////////
    // external data anchoring
    signal input extraInputsHash;  // public

    signal input addedAmountZkp;   // public
    // output 'protocol + relayer fee in ZKP'
    signal input chargedAmountZkp;       // public
    signal input createTime;             // public
    signal input depositAmountPrp;       // public
    signal input withdrawAmountPrp;      // public

    // utxo - hidden part
    signal input utxoCommitment;         // public
    signal input utxoSpendPubKey[2];     // public
    signal input utxoSpendKeyRandom;

    // zAsset
    signal input zAssetId;
    signal input zAssetToken;
    signal input zAssetTokenId;
    signal input zAssetNetwork;
    signal input zAssetOffset;
    signal input zAssetWeight;
    signal input zAssetScale; // public
    signal input zAssetMerkleRoot;
    signal input zAssetPathIndices[ZAssetMerkleTreeDepth];
    signal input zAssetPathElements[ZAssetMerkleTreeDepth];

    // zAccount Input
    signal input zAccountUtxoInId;
    signal input zAccountUtxoInZkpAmount;
    signal input zAccountUtxoInPrpAmount;
    signal input zAccountUtxoInZoneId;
    signal input zAccountUtxoInNetworkId;
    signal input zAccountUtxoInExpiryTime;
    signal input zAccountUtxoInNonce;
    signal input zAccountUtxoInTotalAmountPerTimePeriod;
    signal input zAccountUtxoInCreateTime;
    signal input zAccountUtxoInRootSpendPubKey[2];
    signal input zAccountUtxoInReadPubKey[2];
    signal input zAccountUtxoInNullifierPubKey[2];
    signal input zAccountUtxoInSpendPrivKey;       // TODO: refactor to be unified - should be RootSpend
    signal input zAccountUtxoInNullifierPrivKey;
    signal input zAccountUtxoInMasterEOA;
    signal input zAccountUtxoInSpendKeyRandom;
    signal input zAccountUtxoInCommitment;
    signal input zAccountUtxoInNullifier;  // public
    signal input zAccountUtxoInMerkleTreeSelector[2]; // 2 bits: `00` - Taxi, `10` - Bus, `01` - Ferry
    signal input zAccountUtxoInPathIndices[UtxoMerkleTreeDepth];
    signal input zAccountUtxoInPathElements[UtxoMerkleTreeDepth];

    // zAccount Output
    signal input zAccountUtxoOutZkpAmount;
    signal input zAccountUtxoOutPrpAmount;
    signal input zAccountUtxoOutSpendKeyRandom;
    signal input zAccountUtxoOutCommitment; // public


    // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
    signal input zAccountBlackListLeaf;
    signal input zAccountBlackListMerkleRoot;
    signal input zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth];

    // zZone
    signal input zZoneOriginZoneIDs;
    signal input zZoneTargetZoneIDs;
    signal input zZoneNetworkIDsBitMap;
    signal input zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input zZoneKycExpiryTime;
    signal input zZoneKytExpiryTime;
    signal input zZoneDepositMaxAmount;
    signal input zZoneWithdrawMaxAmount;
    signal input zZoneInternalMaxAmount;
    signal input zZoneMerkleRoot;
    signal input zZonePathElements[ZZoneMerkleTreeDepth];
    signal input zZonePathIndices[ZZoneMerkleTreeDepth];
    signal input zZoneEdDsaPubKey[2];
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;
    signal input zZoneDataEscrowPubKey[2];
    signal input zZoneSealing;

    // zNetworks tree
    // network parameters:
    // 1) is-active - 1 bit (circuit will set it to TRUE ALWAYS)
    // 2) network-id - 6 bit
    // 3) rewards params - all of them: forTxReward, forUtxoReward, forDepositReward
    // 4) daoDataEscrowPubKey[2]
    signal input zNetworkId;
    signal input zNetworkChainId; // public
    signal input zNetworkIDsBitMap;
    signal input zNetworkTreeMerkleRoot;
    signal input zNetworkTreePathElements[ZNetworkMerkleTreeDepth];
    signal input zNetworkTreePathIndices[ZNetworkMerkleTreeDepth];

    signal input daoDataEscrowPubKey[2];
    signal input forTxReward;
    signal input forUtxoReward;
    signal input forDepositReward;

    // static tree merkle root
    // Poseidon of:
    // 1) zAssetMerkleRoot
    // 2) zAccountBlackListMerkleRoot
    // 3) zNetworkTreeMerkleRoot
    // 4) zZoneMerkleRoot
    // 5) trustProvidersMerkleRoot
    signal input trustProvidersMerkleRoot;
    signal input staticTreeMerkleRoot;

    // forest root
    // Poseidon of:
    // 1) UTXO-Taxi-Tree   - 6 levels MT
    // 2) UTXO-Bus-Tree    - 26 levels MT
    // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
    // 4) Static-Tree
    signal input forestMerkleRoot;   // public
    signal input taxiMerkleRoot;
    signal input busMerkleRoot;
    signal input ferryMerkleRoot;

    // salt
    signal input salt;
    signal input saltHash; // public - poseidon(salt)

    // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
    signal input magicalConstraint; // public

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // START OF CODE /////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    var IGNORE_PUBLIC = NonActive();
    var IGNORE_ANCHORED = NonActive();
    var IGNORE_CHECKED_IN_CIRCOMLIB = NonActive();
    var ACTIVE = Active();

    signal rc_extraInputsHash <== ExternalTag()(extraInputsHash);
    signal rc_addedAmountZkp <== Uint96Tag(IGNORE_PUBLIC)(addedAmountZkp);
    signal rc_chargedAmountZkp <== Uint96Tag(IGNORE_PUBLIC)(chargedAmountZkp);

    signal rc_createTime <== Uint32Tag(IGNORE_PUBLIC)(createTime);
    signal rc_depositAmountPrp <== Uint196Tag(IGNORE_PUBLIC)(depositAmountPrp);
    signal rc_withdrawAmountPrp <== Uint196Tag(IGNORE_PUBLIC)(withdrawAmountPrp);
    signal rc_utxoCommitment <== ExternalTag()(utxoCommitment);
    signal rc_utxoSpendPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(utxoSpendPubKey);
    signal rc_utxoSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(utxoSpendKeyRandom);

    signal rc_zAssetId <==  Uint64Tag(IGNORE_ANCHORED)(zAssetId);
    signal rc_zAssetToken <==  Uint168Tag(IGNORE_ANCHORED)(zAssetToken);
    signal rc_zAssetTokenId <== Uint252Tag(IGNORE_ANCHORED)(zAssetTokenId);
    signal rc_zAssetNetwork <== Uint6Tag(IGNORE_ANCHORED)(zAssetNetwork);
    signal rc_zAssetOffset <== Uint32Tag(IGNORE_ANCHORED)(zAssetOffset);
    signal rc_zAssetWeight <== Uint48Tag(IGNORE_ANCHORED)(zAssetWeight);
    signal rc_zAssetScale <== NonZeroUint64Tag(IGNORE_ANCHORED)(zAssetScale);
    signal rc_zAssetMerkleRoot <== SnarkFieldTag()(zAssetMerkleRoot);
    signal rc_zAssetPathIndices[ZAssetMerkleTreeDepth] <== BinaryTagArray(ACTIVE,ZAssetMerkleTreeDepth)(zAssetPathIndices);
    signal rc_zAssetPathElements[ZAssetMerkleTreeDepth] <== SnarkFieldTagArray(ZAssetMerkleTreeDepth)(zAssetPathElements);

    signal rc_zAccountUtxoInId <== Uint24Tag(ACTIVE)(zAccountUtxoInId);
    signal rc_zAccountUtxoInZkpAmount <== Uint64Tag(ACTIVE)(zAccountUtxoInZkpAmount);
    signal rc_zAccountUtxoInPrpAmount <== Uint196Tag(ACTIVE)(zAccountUtxoInPrpAmount);
    signal rc_zAccountUtxoInZoneId <==  Uint16Tag(ACTIVE)(zAccountUtxoInZoneId);
    signal rc_zAccountUtxoInNetworkId <== Uint6Tag(ACTIVE)(zAccountUtxoInNetworkId);
    signal rc_zAccountUtxoInExpiryTime <== Uint32Tag(ACTIVE)(zAccountUtxoInExpiryTime);
    signal rc_zAccountUtxoInNonce <==  Uint32Tag(ACTIVE)(zAccountUtxoInNonce);
    signal rc_zAccountUtxoInTotalAmountPerTimePeriod <==  Uint96Tag(ACTIVE)(zAccountUtxoInTotalAmountPerTimePeriod);
    signal rc_zAccountUtxoInCreateTime <==  Uint32Tag(ACTIVE)(zAccountUtxoInCreateTime);
    signal rc_zAccountUtxoInRootSpendPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountUtxoInRootSpendPubKey);
    signal rc_zAccountUtxoInReadPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountUtxoInReadPubKey);
    signal rc_zAccountUtxoInNullifierPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountUtxoInNullifierPubKey);
    signal rc_zAccountUtxoInSpendPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInSpendPrivKey);
    signal rc_zAccountUtxoInNullifierPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInNullifierPrivKey);
    signal rc_zAccountUtxoInMasterEOA <== Uint160Tag(ACTIVE)(zAccountUtxoInMasterEOA);
    signal rc_zAccountUtxoInSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInSpendKeyRandom);
    signal rc_zAccountUtxoInCommitment <== SnarkFieldTag()(zAccountUtxoInCommitment);
    signal rc_zAccountUtxoInNullifier <== ExternalTag()(zAccountUtxoInNullifier);
    signal rc_zAccountUtxoInMerkleTreeSelector[2] <== BinaryTagArray(ACTIVE,2)(zAccountUtxoInMerkleTreeSelector);
    signal rc_zAccountUtxoInPathIndices[UtxoMerkleTreeDepth] <== BinaryTagArray(ACTIVE,UtxoMerkleTreeDepth)(zAccountUtxoInPathIndices);
    signal rc_zAccountUtxoInPathElements[UtxoMerkleTreeDepth] <== SnarkFieldTagArray(UtxoMerkleTreeDepth)(zAccountUtxoInPathElements);

    signal rc_zAccountUtxoOutZkpAmount <==  Uint64Tag(ACTIVE)(zAccountUtxoOutZkpAmount);
    signal rc_zAccountUtxoOutPrpAmount <== Uint196Tag(ACTIVE)(zAccountUtxoOutPrpAmount);
    signal rc_zAccountUtxoOutSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoOutSpendKeyRandom);
    signal rc_zAccountUtxoOutCommitment <== ExternalTag()(zAccountUtxoOutCommitment);

    signal rc_zAccountBlackListLeaf <== SnarkFieldTag()(zAccountBlackListLeaf);
    signal rc_zAccountBlackListMerkleRoot <== SnarkFieldTag()(zAccountBlackListMerkleRoot);
    signal rc_zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth] <== SnarkFieldTagArray(ZAccountBlackListMerkleTreeDepth)(zAccountBlackListPathElements);

    signal rc_zZoneOriginZoneIDs <== Uint240Tag(IGNORE_ANCHORED)(zZoneOriginZoneIDs);
    signal rc_zZoneTargetZoneIDs <== Uint240Tag(IGNORE_ANCHORED)(zZoneTargetZoneIDs);
    signal rc_zZoneNetworkIDsBitMap <== Uint64Tag(IGNORE_ANCHORED)(zZoneNetworkIDsBitMap);
    signal rc_zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== Uint240Tag(ACTIVE)(zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList);
    signal rc_zZoneKycExpiryTime <== Uint32Tag(IGNORE_ANCHORED)(zZoneKycExpiryTime);
    signal rc_zZoneKytExpiryTime <== Uint32Tag(IGNORE_ANCHORED)(zZoneKytExpiryTime);
    signal rc_zZoneDepositMaxAmount <== Uint96Tag(IGNORE_ANCHORED)(zZoneDepositMaxAmount);
    signal rc_zZoneWithdrawMaxAmount <== Uint96Tag(IGNORE_ANCHORED)(zZoneWithdrawMaxAmount);
    signal rc_zZoneInternalMaxAmount <== Uint96Tag(IGNORE_ANCHORED)(zZoneInternalMaxAmount);
    signal rc_zZoneMerkleRoot <== SnarkFieldTag()(zZoneMerkleRoot);
    signal rc_zZonePathElements[ZZoneMerkleTreeDepth] <== SnarkFieldTagArray(ZZoneMerkleTreeDepth)(zZonePathElements);
    signal rc_zZonePathIndices[ZZoneMerkleTreeDepth] <== BinaryTagArray(ACTIVE,ZZoneMerkleTreeDepth)(zZonePathIndices);
    signal rc_zZoneEdDsaPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(zZoneEdDsaPubKey);
    signal rc_zZoneZAccountIDsBlackList <== Uint240Tag(IGNORE_ANCHORED)(zZoneZAccountIDsBlackList);
    signal rc_zZoneMaximumAmountPerTimePeriod <== Uint96Tag(IGNORE_ANCHORED)(zZoneMaximumAmountPerTimePeriod);
    signal rc_zZoneTimePeriodPerMaximumAmount <== Uint32Tag(IGNORE_ANCHORED)(zZoneTimePeriodPerMaximumAmount);
    signal rc_zZoneDataEscrowPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(zZoneDataEscrowPubKey);
    signal rc_zZoneSealing <== BinaryTag(IGNORE_ANCHORED)(zZoneSealing);

    signal rc_zNetworkId <== Uint6Tag(ACTIVE)(zNetworkId);
    signal rc_zNetworkChainId <== ExternalTag()(zNetworkChainId);
    signal rc_zNetworkIDsBitMap <== Uint64Tag(ACTIVE)(zNetworkIDsBitMap);
    signal rc_zNetworkTreeMerkleRoot <== SnarkFieldTag()(zNetworkTreeMerkleRoot);
    signal rc_zNetworkTreePathElements[ZNetworkMerkleTreeDepth] <== SnarkFieldTagArray(ZNetworkMerkleTreeDepth)(zNetworkTreePathElements);
    signal rc_zNetworkTreePathIndices[ZNetworkMerkleTreeDepth] <== BinaryTagArray(ACTIVE,ZNetworkMerkleTreeDepth)(zNetworkTreePathIndices);

    signal rc_daoDataEscrowPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(daoDataEscrowPubKey);
    signal rc_forTxReward <== Uint40Tag(IGNORE_ANCHORED)(forTxReward);
    signal rc_forUtxoReward <== Uint40Tag(IGNORE_ANCHORED)(forUtxoReward);
    signal rc_forDepositReward <== Uint40Tag(IGNORE_ANCHORED)(forDepositReward);
    signal rc_trustProvidersMerkleRoot <== SnarkFieldTag()(trustProvidersMerkleRoot);
    signal rc_staticTreeMerkleRoot <== ExternalTag()(staticTreeMerkleRoot);
    signal rc_forestMerkleRoot <== ExternalTag()(forestMerkleRoot);
    signal rc_taxiMerkleRoot <== SnarkFieldTag()(taxiMerkleRoot);
    signal rc_busMerkleRoot <== SnarkFieldTag()(busMerkleRoot);
    signal rc_ferryMerkleRoot <== SnarkFieldTag()(ferryMerkleRoot);
    signal rc_salt <== SnarkFieldTag()(salt);
    signal rc_saltHash <== ExternalTag()(saltHash);
    signal rc_magicalConstraint <== ExternalTag()(magicalConstraint);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///// [ - ] - Logic /////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    component ammV1 = AmmV1( UtxoLeftMerkleTreeDepth,
                             UtxoMiddleMerkleTreeDepth,
                             ZNetworkMerkleTreeDepth,
                             ZAssetMerkleTreeDepth,
                             ZAccountBlackListMerkleTreeDepth,
                             ZZoneMerkleTreeDepth );

    ammV1.extraInputsHash <== rc_extraInputsHash;

    ammV1.addedAmountZkp <== rc_addedAmountZkp;
    ammV1.chargedAmountZkp <== rc_chargedAmountZkp;
    ammV1.createTime <== rc_createTime;
    ammV1.depositAmountPrp <== rc_depositAmountPrp;
    ammV1.withdrawAmountPrp <== rc_withdrawAmountPrp;

    ammV1.utxoCommitment <== rc_utxoCommitment;
    ammV1.utxoSpendPubKey <== rc_utxoSpendPubKey;
    ammV1.utxoSpendKeyRandom <== rc_utxoSpendKeyRandom;

    ammV1.zAssetId <== rc_zAssetId;
    ammV1.zAssetToken <== rc_zAssetToken;
    ammV1.zAssetTokenId <== rc_zAssetTokenId;
    ammV1.zAssetNetwork <== rc_zAssetNetwork;
    ammV1.zAssetOffset <== rc_zAssetOffset;
    ammV1.zAssetWeight <== rc_zAssetWeight;
    ammV1.zAssetScale <== rc_zAssetScale;
    ammV1.zAssetMerkleRoot <== rc_zAssetMerkleRoot;
    ammV1.zAssetPathIndices <== rc_zAssetPathIndices;
    ammV1.zAssetPathElements <== rc_zAssetPathElements;

    ammV1.zAccountUtxoInId <== rc_zAccountUtxoInId;
    ammV1.zAccountUtxoInZkpAmount <== rc_zAccountUtxoInZkpAmount;
    ammV1.zAccountUtxoInPrpAmount <== rc_zAccountUtxoInPrpAmount;
    ammV1.zAccountUtxoInZoneId <== rc_zAccountUtxoInZoneId;
    ammV1.zAccountUtxoInNetworkId <== rc_zAccountUtxoInNetworkId;
    ammV1.zAccountUtxoInExpiryTime <== rc_zAccountUtxoInExpiryTime;
    ammV1.zAccountUtxoInNonce <== rc_zAccountUtxoInNonce;
    ammV1.zAccountUtxoInTotalAmountPerTimePeriod <== rc_zAccountUtxoInTotalAmountPerTimePeriod;
    ammV1.zAccountUtxoInCreateTime <== rc_zAccountUtxoInCreateTime;
    ammV1.zAccountUtxoInRootSpendPubKey <== rc_zAccountUtxoInRootSpendPubKey;
    ammV1.zAccountUtxoInReadPubKey <== rc_zAccountUtxoInReadPubKey;
    ammV1.zAccountUtxoInNullifierPubKey <== rc_zAccountUtxoInNullifierPubKey;
    ammV1.zAccountUtxoInSpendPrivKey <== rc_zAccountUtxoInSpendPrivKey;
    ammV1.zAccountUtxoInNullifierPrivKey <== rc_zAccountUtxoInNullifierPrivKey;
    ammV1.zAccountUtxoInMasterEOA <== rc_zAccountUtxoInMasterEOA;
    ammV1.zAccountUtxoInSpendKeyRandom <== rc_zAccountUtxoInSpendKeyRandom;
    ammV1.zAccountUtxoInCommitment <== rc_zAccountUtxoInCommitment;
    ammV1.zAccountUtxoInNullifier <== rc_zAccountUtxoInNullifier;
    ammV1.zAccountUtxoInMerkleTreeSelector <== rc_zAccountUtxoInMerkleTreeSelector;
    ammV1.zAccountUtxoInPathIndices <== rc_zAccountUtxoInPathIndices;
    ammV1.zAccountUtxoInPathElements <== rc_zAccountUtxoInPathElements;

    ammV1.zAccountUtxoOutZkpAmount <== rc_zAccountUtxoOutZkpAmount;
    ammV1.zAccountUtxoOutPrpAmount <== rc_zAccountUtxoOutPrpAmount;
    ammV1.zAccountUtxoOutSpendKeyRandom <== rc_zAccountUtxoOutSpendKeyRandom;
    ammV1.zAccountUtxoOutCommitment <== rc_zAccountUtxoOutCommitment;

    ammV1.zAccountBlackListLeaf <== rc_zAccountBlackListLeaf;
    ammV1.zAccountBlackListMerkleRoot <== rc_zAccountBlackListMerkleRoot;
    ammV1.zAccountBlackListPathElements <== rc_zAccountBlackListPathElements;

    ammV1.zZoneOriginZoneIDs <== rc_zZoneOriginZoneIDs;
    ammV1.zZoneTargetZoneIDs <== rc_zZoneTargetZoneIDs;
    ammV1.zZoneNetworkIDsBitMap <== rc_zZoneNetworkIDsBitMap;
    ammV1.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== rc_zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    ammV1.zZoneKycExpiryTime <== rc_zZoneKycExpiryTime;
    ammV1.zZoneKytExpiryTime <== rc_zZoneKytExpiryTime;
    ammV1.zZoneDepositMaxAmount <== rc_zZoneDepositMaxAmount;
    ammV1.zZoneWithdrawMaxAmount <== rc_zZoneWithdrawMaxAmount;
    ammV1.zZoneInternalMaxAmount <== rc_zZoneInternalMaxAmount;
    ammV1.zZoneMerkleRoot <== rc_zZoneMerkleRoot;
    ammV1.zZonePathElements <== rc_zZonePathElements;
    ammV1.zZonePathIndices <== rc_zZonePathIndices;
    ammV1.zZoneEdDsaPubKey <== rc_zZoneEdDsaPubKey;
    ammV1.zZoneZAccountIDsBlackList <== rc_zZoneZAccountIDsBlackList;
    ammV1.zZoneMaximumAmountPerTimePeriod <== rc_zZoneMaximumAmountPerTimePeriod;
    ammV1.zZoneTimePeriodPerMaximumAmount <== rc_zZoneTimePeriodPerMaximumAmount;
    ammV1.zZoneDataEscrowPubKey[0] <== rc_zZoneDataEscrowPubKey[0];
    ammV1.zZoneDataEscrowPubKey[1] <== rc_zZoneDataEscrowPubKey[1];
    ammV1.zZoneSealing <== rc_zZoneSealing;

    ammV1.zNetworkId <== rc_zNetworkId;
    ammV1.zNetworkChainId <== rc_zNetworkChainId;
    ammV1.zNetworkIDsBitMap <== rc_zNetworkIDsBitMap;
    ammV1.zNetworkTreeMerkleRoot <== rc_zNetworkTreeMerkleRoot;
    ammV1.zNetworkTreePathElements <== rc_zNetworkTreePathElements;
    ammV1.zNetworkTreePathIndices <== rc_zNetworkTreePathIndices;

    ammV1.daoDataEscrowPubKey <== rc_daoDataEscrowPubKey;
    ammV1.forTxReward <== rc_forTxReward;
    ammV1.forUtxoReward <== rc_forUtxoReward;
    ammV1.forDepositReward <== rc_forDepositReward;

    ammV1.trustProvidersMerkleRoot <== rc_trustProvidersMerkleRoot;
    ammV1.staticTreeMerkleRoot <== rc_staticTreeMerkleRoot;
    ammV1.forestMerkleRoot <== rc_forestMerkleRoot;
    ammV1.taxiMerkleRoot <== rc_taxiMerkleRoot;
    ammV1.busMerkleRoot <== rc_busMerkleRoot;
    ammV1.ferryMerkleRoot <== rc_ferryMerkleRoot;

    ammV1.salt <== rc_salt;
    ammV1.saltHash <== rc_saltHash;
    ammV1.magicalConstraint <== rc_magicalConstraint;
}
