//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./zAccountRenewalV1.circom";
include "./templates/utils.circom";

template ZAccountRenewalV1Top ( UtxoLeftMerkleTreeDepth,
                                UtxoMiddleMerkleTreeDepth,
                                ZNetworkMerkleTreeDepth,
                                ZAssetMerkleTreeDepth,
                                ZAccountBlackListMerkleTreeDepth,
                                ZZoneMerkleTreeDepth,
                                TrustProvidersMerkleTreeDepth ) {
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
    signal input chargedAmountZkp; // public

    // zAsset
    signal input zAssetId;
    signal input zAssetToken;
    signal input zAssetTokenId;
    signal input zAssetNetwork;
    signal input zAssetOffset;
    signal input zAssetWeight;
    signal input zAssetScale;
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
    signal input zAccountUtxoInRootSpendPrivKey;
    signal input zAccountUtxoInRootSpendPubKey[2];
    signal input zAccountUtxoInReadPubKey[2];
    signal input zAccountUtxoInNullifierPubKey[2];
    signal input zAccountUtxoInMasterEOA;
    signal input zAccountUtxoInSpendKeyRandom;
    signal input zAccountUtxoInNullifierPrivKey;
    signal input zAccountUtxoInCommitment; // public
    signal input zAccountUtxoInNullifier;  // public
    signal input zAccountUtxoInMerkleTreeSelector[2]; // 2 bits: `00` - Taxi, `10` - Bus, `01` - Ferry
    signal input zAccountUtxoInPathIndices[UtxoMerkleTreeDepth];
    signal input zAccountUtxoInPathElements[UtxoMerkleTreeDepth];

    // zAccount Output
    signal input zAccountUtxoOutZkpAmount;
    signal input zAccountUtxoOutExpiryTime;
    signal input zAccountUtxoOutCreateTime; // public
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

    // KYC
    signal input kycEdDsaPubKey[2];
    signal input kycEdDsaPubKeyExpiryTime;
    signal input trustProvidersMerkleRoot;
    signal input kycPathElements[TrustProvidersMerkleTreeDepth];
    signal input kycPathIndices[TrustProvidersMerkleTreeDepth];
    signal input kycMerkleTreeLeafIDsAndRulesOffset;
    // signed message
    signal input kycSignedMessagePackageType;         // 1 - KYC
    signal input kycSignedMessageTimestamp;
    signal input kycSignedMessageSender;              // 0
    signal input kycSignedMessageReceiver;            // 0
    signal input kycSignedMessageSessionId;
    signal input kycSignedMessageRuleId;
    signal input kycSignedMessageSigner;
    signal input kycSignedMessageHash;                // public
    signal input kycSignature[3];                     // S,R8x,R8y

    // zNetworks tree
    // network parameters:
    // 1) is-active - 1 bit (circuit will set it to TRUE ALWAYS)
    // 2) network-id - 6 bit
    // 3) rewards params - all of them: forTxReward, forUtxoReward, forDepositReward
    // 4) daoDataEscrowPubKey[2]
    signal input zNetworkId;
    signal input zNetworkChainId;
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
    signal input staticTreeMerkleRoot;

    // forest root
    // Poseidon of:
    // 1) UTXO-Taxi-Tree   - 8 levels MT
    // 2) UTXO-Bus-Tree    - 26 levels MT
    // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
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

    signal rc_zAssetId <==  Uint64Tag(IGNORE_ANCHORED)(zAssetId);
    signal rc_zAssetToken <==  Uint168Tag(IGNORE_ANCHORED)(zAssetToken);
    signal rc_zAssetTokenId <== Uint252Tag(IGNORE_ANCHORED)(zAssetTokenId);
    signal rc_zAssetNetwork <== Uint6Tag(IGNORE_ANCHORED)(zAssetNetwork);
    signal rc_zAssetOffset <== Uint32Tag(IGNORE_ANCHORED)(zAssetOffset);
    signal rc_zAssetWeight <== NonZeroUint48Tag(IGNORE_ANCHORED)(zAssetWeight);
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
    signal rc_zAccountUtxoInRootSpendPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInRootSpendPrivKey);
    signal rc_zAccountUtxoInRootSpendPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountUtxoInRootSpendPubKey);
    signal rc_zAccountUtxoInReadPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountUtxoInReadPubKey);
    signal rc_zAccountUtxoInNullifierPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountUtxoInNullifierPubKey);
    signal rc_zAccountUtxoInMasterEOA <== Uint160Tag(ACTIVE)(zAccountUtxoInMasterEOA);
    signal rc_zAccountUtxoInSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInSpendKeyRandom);
    signal rc_zAccountUtxoInNullifierPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInNullifierPrivKey);
    signal rc_zAccountUtxoInCommitment <== ExternalTag()(zAccountUtxoInCommitment);
    signal rc_zAccountUtxoInNullifier <== ExternalTag()(zAccountUtxoInNullifier);
    signal rc_zAccountUtxoInMerkleTreeSelector[2] <== BinaryTagArray(ACTIVE,2)(zAccountUtxoInMerkleTreeSelector);
    signal rc_zAccountUtxoInPathIndices[UtxoMerkleTreeDepth] <== BinaryTagArray(ACTIVE,UtxoMerkleTreeDepth)(zAccountUtxoInPathIndices);
    signal rc_zAccountUtxoInPathElements[UtxoMerkleTreeDepth] <== SnarkFieldTagArray(UtxoMerkleTreeDepth)(zAccountUtxoInPathElements);

    signal rc_zAccountUtxoOutZkpAmount <==  Uint64Tag(ACTIVE)(zAccountUtxoOutZkpAmount);
    signal rc_zAccountUtxoOutExpiryTime <== Uint32Tag(ACTIVE)(zAccountUtxoOutExpiryTime);
    signal rc_zAccountUtxoOutCreateTime <== Uint32Tag(ACTIVE)(zAccountUtxoOutCreateTime);
    signal rc_zAccountUtxoOutSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoOutSpendKeyRandom);
    signal rc_zAccountUtxoOutCommitment <== ExternalTag()(zAccountUtxoOutCommitment);

    signal rc_zAccountBlackListLeaf <== SnarkFieldTag()(zAccountBlackListLeaf);
    signal rc_zAccountBlackListMerkleRoot <== SnarkFieldTag()(zAccountBlackListMerkleRoot);
    signal rc_zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth] <== SnarkFieldTagArray(ZAccountBlackListMerkleTreeDepth)(zAccountBlackListPathElements);

    signal rc_zZoneOriginZoneIDs <== Uint16Tag(IGNORE_ANCHORED)(zZoneOriginZoneIDs);
    signal rc_zZoneTargetZoneIDs <== Uint16Tag(IGNORE_ANCHORED)(zZoneTargetZoneIDs);
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

    signal rc_kycEdDsaPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(kycEdDsaPubKey);
    signal rc_kycEdDsaPubKeyExpiryTime <== Uint32Tag(ACTIVE)(kycEdDsaPubKeyExpiryTime);
    signal rc_trustProvidersMerkleRoot <== SnarkFieldTag()(trustProvidersMerkleRoot);
    signal rc_kycPathElements[TrustProvidersMerkleTreeDepth] <== SnarkFieldTagArray(TrustProvidersMerkleTreeDepth)(kycPathElements);
    signal rc_kycPathIndices[TrustProvidersMerkleTreeDepth] <== BinaryTagArray(ACTIVE,TrustProvidersMerkleTreeDepth)(kycPathIndices);
    signal rc_kycMerkleTreeLeafIDsAndRulesOffset <== Uint4Tag(ACTIVE)(kycMerkleTreeLeafIDsAndRulesOffset);
    signal rc_kycSignedMessagePackageType <== IgnoreTag()(kycSignedMessagePackageType);
    signal rc_kycSignedMessageTimestamp <== IgnoreTag()(kycSignedMessageTimestamp);
    signal rc_kycSignedMessageSender <== ExternalTag()(kycSignedMessageSender);
    signal rc_kycSignedMessageReceiver <== ExternalTag()(kycSignedMessageReceiver);
    signal rc_kycSignedMessageSessionId <== IgnoreTag()(kycSignedMessageSessionId);
    signal rc_kycSignedMessageRuleId <== Uint8Tag(ACTIVE)(kycSignedMessageRuleId);
    signal rc_kycSignedMessageSigner <== Uint160Tag(ACTIVE)(kycSignedMessageSigner);
    signal rc_kycSignedMessageHash <== ExternalTag()(kycSignedMessageHash);
    signal rc_kycSignature[3] <== BabyJubJubSubOrderTagArray(IGNORE_CHECKED_IN_CIRCOMLIB,3)(kycSignature);

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
    signal rc_staticTreeMerkleRoot <== ExternalTag()(staticTreeMerkleRoot);
    signal rc_forestMerkleRoot <== ExternalTag()(forestMerkleRoot);
    signal rc_taxiMerkleRoot <== SnarkFieldTag()(taxiMerkleRoot);
    signal rc_busMerkleRoot <== SnarkFieldTag()(busMerkleRoot);
    signal rc_ferryMerkleRoot <== SnarkFieldTag()(ferryMerkleRoot);
    signal rc_salt <== SnarkFieldTag()(salt);
    signal rc_saltHash <== ExternalTag()(saltHash);
    signal rc_magicalConstraint <== ExternalTag()(magicalConstraint);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [ - ] - Logic /////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component zAccountRenewalV1 = ZAccountRenewalV1( UtxoLeftMerkleTreeDepth,
                                                     UtxoMiddleMerkleTreeDepth,
                                                     ZNetworkMerkleTreeDepth,
                                                     ZAssetMerkleTreeDepth,
                                                     ZAccountBlackListMerkleTreeDepth,
                                                     ZZoneMerkleTreeDepth,
                                                     TrustProvidersMerkleTreeDepth );

    zAccountRenewalV1.extraInputsHash <== rc_extraInputsHash;
    zAccountRenewalV1.addedAmountZkp <== rc_addedAmountZkp;
    zAccountRenewalV1.chargedAmountZkp <== rc_chargedAmountZkp;

    zAccountRenewalV1.zAssetId <== rc_zAssetId;
    zAccountRenewalV1.zAssetToken <== rc_zAssetToken;
    zAccountRenewalV1.zAssetTokenId <== rc_zAssetTokenId;
    zAccountRenewalV1.zAssetNetwork <== rc_zAssetNetwork;
    zAccountRenewalV1.zAssetOffset <== rc_zAssetOffset;
    zAccountRenewalV1.zAssetWeight <== rc_zAssetWeight;
    zAccountRenewalV1.zAssetScale <== rc_zAssetScale;
    zAccountRenewalV1.zAssetMerkleRoot <== rc_zAssetMerkleRoot;
    zAccountRenewalV1.zAssetPathIndices <== rc_zAssetPathIndices;
    zAccountRenewalV1.zAssetPathElements <== rc_zAssetPathElements;

    zAccountRenewalV1.zAccountUtxoInId <== rc_zAccountUtxoInId;
    zAccountRenewalV1.zAccountUtxoInZkpAmount <== rc_zAccountUtxoInZkpAmount;
    zAccountRenewalV1.zAccountUtxoInPrpAmount <== rc_zAccountUtxoInPrpAmount;
    zAccountRenewalV1.zAccountUtxoInZoneId <== rc_zAccountUtxoInZoneId;
    zAccountRenewalV1.zAccountUtxoInNetworkId <== rc_zAccountUtxoInNetworkId;
    zAccountRenewalV1.zAccountUtxoInExpiryTime <== rc_zAccountUtxoInExpiryTime;
    zAccountRenewalV1.zAccountUtxoInNonce <== rc_zAccountUtxoInNonce;
    zAccountRenewalV1.zAccountUtxoInTotalAmountPerTimePeriod <== rc_zAccountUtxoInTotalAmountPerTimePeriod;
    zAccountRenewalV1.zAccountUtxoInCreateTime <== rc_zAccountUtxoInCreateTime;
    zAccountRenewalV1.zAccountUtxoInRootSpendPrivKey <== rc_zAccountUtxoInRootSpendPrivKey;
    zAccountRenewalV1.zAccountUtxoInRootSpendPubKey <== rc_zAccountUtxoInRootSpendPubKey;
    zAccountRenewalV1.zAccountUtxoInReadPubKey <== rc_zAccountUtxoInReadPubKey;
    zAccountRenewalV1.zAccountUtxoInNullifierPubKey <== rc_zAccountUtxoInNullifierPubKey;
    zAccountRenewalV1.zAccountUtxoInMasterEOA <== rc_zAccountUtxoInMasterEOA;
    zAccountRenewalV1.zAccountUtxoInSpendKeyRandom <== rc_zAccountUtxoInSpendKeyRandom;
    zAccountRenewalV1.zAccountUtxoInNullifierPrivKey <== rc_zAccountUtxoInNullifierPrivKey;
    zAccountRenewalV1.zAccountUtxoInCommitment <== rc_zAccountUtxoInCommitment;
    zAccountRenewalV1.zAccountUtxoInNullifier <== rc_zAccountUtxoInNullifier;
    zAccountRenewalV1.zAccountUtxoInMerkleTreeSelector <== rc_zAccountUtxoInMerkleTreeSelector;
    zAccountRenewalV1.zAccountUtxoInPathIndices <== rc_zAccountUtxoInPathIndices;
    zAccountRenewalV1.zAccountUtxoInPathElements <== rc_zAccountUtxoInPathElements;

    zAccountRenewalV1.zAccountUtxoOutZkpAmount <== rc_zAccountUtxoOutZkpAmount;
    zAccountRenewalV1.zAccountUtxoOutExpiryTime <== rc_zAccountUtxoOutExpiryTime;
    zAccountRenewalV1.zAccountUtxoOutCreateTime <== rc_zAccountUtxoOutCreateTime;
    zAccountRenewalV1.zAccountUtxoOutSpendKeyRandom <== rc_zAccountUtxoOutSpendKeyRandom;
    zAccountRenewalV1.zAccountUtxoOutCommitment <== rc_zAccountUtxoOutCommitment;

    zAccountRenewalV1.zAccountBlackListLeaf <== rc_zAccountBlackListLeaf;
    zAccountRenewalV1.zAccountBlackListMerkleRoot <== rc_zAccountBlackListMerkleRoot;
    zAccountRenewalV1.zAccountBlackListPathElements <== rc_zAccountBlackListPathElements;

    zAccountRenewalV1.zZoneOriginZoneIDs <== rc_zZoneOriginZoneIDs;
    zAccountRenewalV1.zZoneTargetZoneIDs <== rc_zZoneTargetZoneIDs;
    zAccountRenewalV1.zZoneNetworkIDsBitMap <== rc_zZoneNetworkIDsBitMap;
    zAccountRenewalV1.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== rc_zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zAccountRenewalV1.zZoneKycExpiryTime <== rc_zZoneKycExpiryTime;
    zAccountRenewalV1.zZoneKytExpiryTime <== rc_zZoneKytExpiryTime;
    zAccountRenewalV1.zZoneDepositMaxAmount <== rc_zZoneDepositMaxAmount;
    zAccountRenewalV1.zZoneWithdrawMaxAmount <== rc_zZoneWithdrawMaxAmount;
    zAccountRenewalV1.zZoneInternalMaxAmount <== rc_zZoneInternalMaxAmount;
    zAccountRenewalV1.zZoneMerkleRoot <== rc_zZoneMerkleRoot;
    zAccountRenewalV1.zZonePathElements <== rc_zZonePathElements;
    zAccountRenewalV1.zZonePathIndices <== rc_zZonePathIndices;
    zAccountRenewalV1.zZoneEdDsaPubKey <== rc_zZoneEdDsaPubKey;
    zAccountRenewalV1.zZoneZAccountIDsBlackList <== rc_zZoneZAccountIDsBlackList;
    zAccountRenewalV1.zZoneMaximumAmountPerTimePeriod <== rc_zZoneMaximumAmountPerTimePeriod;
    zAccountRenewalV1.zZoneTimePeriodPerMaximumAmount <== rc_zZoneTimePeriodPerMaximumAmount;
    zAccountRenewalV1.zZoneDataEscrowPubKey[0] <== rc_zZoneDataEscrowPubKey[0];
    zAccountRenewalV1.zZoneDataEscrowPubKey[1] <== rc_zZoneDataEscrowPubKey[1];
    zAccountRenewalV1.zZoneSealing <== rc_zZoneSealing;

    zAccountRenewalV1.kycEdDsaPubKey <== rc_kycEdDsaPubKey;
    zAccountRenewalV1.kycEdDsaPubKeyExpiryTime <== rc_kycEdDsaPubKeyExpiryTime;
    zAccountRenewalV1.trustProvidersMerkleRoot <== rc_trustProvidersMerkleRoot;
    zAccountRenewalV1.kycPathElements <== rc_kycPathElements;
    zAccountRenewalV1.kycPathIndices <== rc_kycPathIndices;
    zAccountRenewalV1.kycMerkleTreeLeafIDsAndRulesOffset <== rc_kycMerkleTreeLeafIDsAndRulesOffset;
    zAccountRenewalV1.kycSignedMessagePackageType <== rc_kycSignedMessagePackageType;
    zAccountRenewalV1.kycSignedMessageTimestamp <== rc_kycSignedMessageTimestamp;
    zAccountRenewalV1.kycSignedMessageSender <== rc_kycSignedMessageSender;
    zAccountRenewalV1.kycSignedMessageReceiver <== rc_kycSignedMessageReceiver;
    zAccountRenewalV1.kycSignedMessageSessionId <== rc_kycSignedMessageSessionId;
    zAccountRenewalV1.kycSignedMessageRuleId <== rc_kycSignedMessageRuleId;
    zAccountRenewalV1.kycSignedMessageSigner <== rc_kycSignedMessageSigner;
    zAccountRenewalV1.kycSignedMessageHash <== rc_kycSignedMessageHash;
    zAccountRenewalV1.kycSignature <== rc_kycSignature;

    zAccountRenewalV1.zNetworkId <== rc_zNetworkId;
    zAccountRenewalV1.zNetworkChainId <== rc_zNetworkChainId;
    zAccountRenewalV1.zNetworkIDsBitMap <== rc_zNetworkIDsBitMap;
    zAccountRenewalV1.zNetworkTreeMerkleRoot <== rc_zNetworkTreeMerkleRoot;
    zAccountRenewalV1.zNetworkTreePathElements <== rc_zNetworkTreePathElements;
    zAccountRenewalV1.zNetworkTreePathIndices <== rc_zNetworkTreePathIndices;

    zAccountRenewalV1.daoDataEscrowPubKey <== rc_daoDataEscrowPubKey;
    zAccountRenewalV1.forTxReward <== rc_forTxReward;
    zAccountRenewalV1.forUtxoReward <== rc_forUtxoReward;
    zAccountRenewalV1.forDepositReward <== rc_forDepositReward;

    zAccountRenewalV1.staticTreeMerkleRoot <== rc_staticTreeMerkleRoot;

    zAccountRenewalV1.forestMerkleRoot <== rc_forestMerkleRoot;
    zAccountRenewalV1.taxiMerkleRoot <== rc_taxiMerkleRoot;
    zAccountRenewalV1.busMerkleRoot <== rc_busMerkleRoot;
    zAccountRenewalV1.ferryMerkleRoot <== rc_ferryMerkleRoot;

    zAccountRenewalV1.salt <== rc_salt;
    zAccountRenewalV1.saltHash <== rc_saltHash;

    zAccountRenewalV1.magicalConstraint <== rc_magicalConstraint;
}
