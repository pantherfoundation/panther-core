// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./zAccountRegistrationV1.circom";
include "./templates/utils.circom";

template ZAccountRegistrationV1Top ( ZNetworkMerkleTreeDepth,
                                     ZAssetMerkleTreeDepth,
                                     ZAccountBlackListMerkleTreeDepth,
                                     ZZoneMerkleTreeDepth,
                                     TrustProvidersMerkleTreeDepth,
                                     IsTestNet ) {
    // external data anchoring
    signal input extraInputsHash;  // public

    // zkp amounts (not scaled)
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

    // zAccount
    signal input zAccountId; // public
    signal input zAccountZkpAmount;
    signal input zAccountPrpAmount;
    signal input zAccountZoneId;
    signal input zAccountNetworkId;
    signal input zAccountExpiryTime;
    signal input zAccountNonce;
    signal input zAccountTotalAmountPerTimePeriod;
    signal input zAccountCreateTime;
    signal input zAccountRootSpendPubKey[2]; // public
    signal input zAccountReadPubKey[2];      // public
    signal input zAccountNullifierPubKey[2]; // public
    signal input zAccountMasterEOA;          // public
    signal input zAccountRootSpendPrivKey;
    signal input zAccountReadPrivKey;
    signal input zAccountNullifierPrivKey;
    signal input zAccountSpendKeyRandom;
    signal input zAccountNullifier;  // public
    signal input zAccountCommitment; // public

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
    signal input kycSignedMessageChargedAmountZkp;
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
    signal rc_zAssetWeight <== Uint48Tag(IGNORE_ANCHORED)(zAssetWeight);
    signal rc_zAssetScale <== NonZeroUint64Tag(IGNORE_ANCHORED)(zAssetScale);
    signal rc_zAssetMerkleRoot <== SnarkFieldTag()(zAssetMerkleRoot);
    signal rc_zAssetPathIndices[ZAssetMerkleTreeDepth] <== BinaryTagArray(ACTIVE,ZAssetMerkleTreeDepth)(zAssetPathIndices);
    signal rc_zAssetPathElements[ZAssetMerkleTreeDepth] <== SnarkFieldTagArray(ZAssetMerkleTreeDepth)(zAssetPathElements);

    signal rc_zAccountId <== Uint24Tag(ACTIVE)(zAccountId);
    signal rc_zAccountZkpAmount <== Uint64Tag(ACTIVE)(zAccountZkpAmount);
    signal rc_zAccountPrpAmount <== Uint196Tag(ACTIVE)(zAccountPrpAmount);
    signal rc_zAccountZoneId <== Uint16Tag(ACTIVE)(zAccountZoneId);
    signal rc_zAccountNetworkId <== Uint6Tag(ACTIVE)(zAccountNetworkId);
    signal rc_zAccountExpiryTime <== Uint32Tag(ACTIVE)(zAccountExpiryTime);
    signal rc_zAccountNonce <== Uint32Tag(ACTIVE)(zAccountNonce);
    signal rc_zAccountTotalAmountPerTimePeriod <== Uint96Tag(ACTIVE)(zAccountTotalAmountPerTimePeriod);
    signal rc_zAccountCreateTime <== Uint32Tag(ACTIVE)(zAccountCreateTime);
    signal rc_zAccountRootSpendPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountRootSpendPubKey);
    signal rc_zAccountReadPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountReadPubKey);
    signal rc_zAccountNullifierPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(zAccountNullifierPubKey);
    signal rc_zAccountMasterEOA <== Uint160Tag(ACTIVE)(zAccountMasterEOA);
    signal rc_zAccountRootSpendPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountRootSpendPrivKey);
    signal rc_zAccountReadPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountReadPrivKey);
    signal rc_zAccountNullifierPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountNullifierPrivKey);
    signal rc_zAccountSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(zAccountSpendKeyRandom);
    signal rc_zAccountNullifier <== ExternalTag()(zAccountNullifier);
    signal rc_zAccountCommitment <== ExternalTag()(zAccountCommitment);

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
    signal rc_kycSignedMessageChargedAmountZkp <== Uint96Tag(ACTIVE)(kycSignedMessageChargedAmountZkp);
    signal rc_kycSignedMessageHash <== ExternalTag()(kycSignedMessageHash);

    // Range checking for the signature components (R8 and S) are enforced in the EdDSAPoseidonVerifier() of circomlib itself.
    // Hence adding additional range checks for signature components (R8 and S) are redundant.
    signal rc_kycSignature[3] <== kycSignature;

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
    component zAccountRegistrationV1 = ZAccountRegistrationV1( ZNetworkMerkleTreeDepth,
                                                               ZAssetMerkleTreeDepth,
                                                               ZAccountBlackListMerkleTreeDepth,
                                                               ZZoneMerkleTreeDepth,
                                                               TrustProvidersMerkleTreeDepth,
                                                               IsTestNet );

    zAccountRegistrationV1.extraInputsHash <== rc_extraInputsHash;
    zAccountRegistrationV1.addedAmountZkp <== rc_addedAmountZkp;
    zAccountRegistrationV1.chargedAmountZkp <== rc_chargedAmountZkp;

    zAccountRegistrationV1.zAssetId <== rc_zAssetId;
    zAccountRegistrationV1.zAssetToken <== rc_zAssetToken;
    zAccountRegistrationV1.zAssetTokenId <== rc_zAssetTokenId;
    zAccountRegistrationV1.zAssetNetwork <== rc_zAssetNetwork;
    zAccountRegistrationV1.zAssetOffset <== rc_zAssetOffset;
    zAccountRegistrationV1.zAssetWeight <== rc_zAssetWeight;
    zAccountRegistrationV1.zAssetScale <== rc_zAssetScale;
    zAccountRegistrationV1.zAssetMerkleRoot <== rc_zAssetMerkleRoot;
    zAccountRegistrationV1.zAssetPathIndices <== rc_zAssetPathIndices;
    zAccountRegistrationV1.zAssetPathElements <== rc_zAssetPathElements;

    zAccountRegistrationV1.zAccountId <== rc_zAccountId;
    zAccountRegistrationV1.zAccountZkpAmount <== rc_zAccountZkpAmount;
    zAccountRegistrationV1.zAccountPrpAmount <== rc_zAccountPrpAmount;
    zAccountRegistrationV1.zAccountZoneId <== rc_zAccountZoneId;
    zAccountRegistrationV1.zAccountNetworkId <== rc_zAccountNetworkId;
    zAccountRegistrationV1.zAccountExpiryTime <== rc_zAccountExpiryTime;
    zAccountRegistrationV1.zAccountNonce <== rc_zAccountNonce;
    zAccountRegistrationV1.zAccountTotalAmountPerTimePeriod <== rc_zAccountTotalAmountPerTimePeriod;
    zAccountRegistrationV1.zAccountCreateTime <== rc_zAccountCreateTime;
    zAccountRegistrationV1.zAccountRootSpendPubKey <== rc_zAccountRootSpendPubKey;
    zAccountRegistrationV1.zAccountReadPubKey <== rc_zAccountReadPubKey;
    zAccountRegistrationV1.zAccountNullifierPubKey <== rc_zAccountNullifierPubKey;
    zAccountRegistrationV1.zAccountMasterEOA <== rc_zAccountMasterEOA;
    zAccountRegistrationV1.zAccountRootSpendPrivKey <== rc_zAccountRootSpendPrivKey;
    zAccountRegistrationV1.zAccountReadPrivKey <== rc_zAccountReadPrivKey;
    zAccountRegistrationV1.zAccountNullifierPrivKey <== rc_zAccountNullifierPrivKey;
    zAccountRegistrationV1.zAccountSpendKeyRandom <== rc_zAccountSpendKeyRandom;
    zAccountRegistrationV1.zAccountNullifier <== rc_zAccountNullifier;
    zAccountRegistrationV1.zAccountCommitment <== rc_zAccountCommitment;

    zAccountRegistrationV1.zAccountBlackListLeaf <== rc_zAccountBlackListLeaf;
    zAccountRegistrationV1.zAccountBlackListMerkleRoot <== rc_zAccountBlackListMerkleRoot;
    zAccountRegistrationV1.zAccountBlackListPathElements <== rc_zAccountBlackListPathElements;

    zAccountRegistrationV1.zZoneOriginZoneIDs <== rc_zZoneOriginZoneIDs;
    zAccountRegistrationV1.zZoneTargetZoneIDs <== rc_zZoneTargetZoneIDs;
    zAccountRegistrationV1.zZoneNetworkIDsBitMap <== rc_zZoneNetworkIDsBitMap;
    zAccountRegistrationV1.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== rc_zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zAccountRegistrationV1.zZoneKycExpiryTime <== rc_zZoneKycExpiryTime;
    zAccountRegistrationV1.zZoneKytExpiryTime <== rc_zZoneKytExpiryTime;
    zAccountRegistrationV1.zZoneDepositMaxAmount <== rc_zZoneDepositMaxAmount;
    zAccountRegistrationV1.zZoneWithdrawMaxAmount <== rc_zZoneWithdrawMaxAmount;
    zAccountRegistrationV1.zZoneInternalMaxAmount <== rc_zZoneInternalMaxAmount;
    zAccountRegistrationV1.zZoneMerkleRoot <== rc_zZoneMerkleRoot;
    zAccountRegistrationV1.zZonePathElements <== rc_zZonePathElements;
    zAccountRegistrationV1.zZonePathIndices <== rc_zZonePathIndices;
    zAccountRegistrationV1.zZoneEdDsaPubKey<== rc_zZoneEdDsaPubKey;
    zAccountRegistrationV1.zZoneZAccountIDsBlackList <== rc_zZoneZAccountIDsBlackList;
    zAccountRegistrationV1.zZoneMaximumAmountPerTimePeriod <== rc_zZoneMaximumAmountPerTimePeriod;
    zAccountRegistrationV1.zZoneTimePeriodPerMaximumAmount <== rc_zZoneTimePeriodPerMaximumAmount;
    zAccountRegistrationV1.zZoneDataEscrowPubKey[0] <== rc_zZoneDataEscrowPubKey[0];
    zAccountRegistrationV1.zZoneDataEscrowPubKey[1] <== rc_zZoneDataEscrowPubKey[1];
    zAccountRegistrationV1.zZoneSealing <== rc_zZoneSealing;

    zAccountRegistrationV1.kycEdDsaPubKey <== rc_kycEdDsaPubKey;
    zAccountRegistrationV1.kycEdDsaPubKeyExpiryTime <== rc_kycEdDsaPubKeyExpiryTime;
    zAccountRegistrationV1.trustProvidersMerkleRoot <== rc_trustProvidersMerkleRoot;
    zAccountRegistrationV1.kycPathElements <== rc_kycPathElements;
    zAccountRegistrationV1.kycPathIndices <== rc_kycPathIndices;
    zAccountRegistrationV1.kycMerkleTreeLeafIDsAndRulesOffset <== rc_kycMerkleTreeLeafIDsAndRulesOffset;

    zAccountRegistrationV1.kycSignedMessagePackageType <== rc_kycSignedMessagePackageType;
    zAccountRegistrationV1.kycSignedMessageTimestamp <== rc_kycSignedMessageTimestamp;
    zAccountRegistrationV1.kycSignedMessageSender <== rc_kycSignedMessageSender;
    zAccountRegistrationV1.kycSignedMessageReceiver <== rc_kycSignedMessageReceiver;
    zAccountRegistrationV1.kycSignedMessageSessionId <== rc_kycSignedMessageSessionId;
    zAccountRegistrationV1.kycSignedMessageRuleId <== rc_kycSignedMessageRuleId;
    zAccountRegistrationV1.kycSignedMessageSigner <== rc_kycSignedMessageSigner;
    zAccountRegistrationV1.kycSignedMessageChargedAmountZkp <== rc_kycSignedMessageChargedAmountZkp;
    zAccountRegistrationV1.kycSignedMessageHash <== rc_kycSignedMessageHash;
    zAccountRegistrationV1.kycSignature <== rc_kycSignature;

    zAccountRegistrationV1.zNetworkId <== rc_zNetworkId;
    zAccountRegistrationV1.zNetworkChainId <== rc_zNetworkChainId;
    zAccountRegistrationV1.zNetworkIDsBitMap <== rc_zNetworkIDsBitMap;
    zAccountRegistrationV1.zNetworkTreeMerkleRoot <== rc_zNetworkTreeMerkleRoot;
    zAccountRegistrationV1.zNetworkTreePathElements <== rc_zNetworkTreePathElements;
    zAccountRegistrationV1.zNetworkTreePathIndices <== rc_zNetworkTreePathIndices;

    zAccountRegistrationV1.daoDataEscrowPubKey <== rc_daoDataEscrowPubKey;
    zAccountRegistrationV1.forTxReward <== rc_forTxReward;
    zAccountRegistrationV1.forUtxoReward <== rc_forUtxoReward;
    zAccountRegistrationV1.forDepositReward <== rc_forDepositReward;

    zAccountRegistrationV1.staticTreeMerkleRoot <== rc_staticTreeMerkleRoot;

    zAccountRegistrationV1.forestMerkleRoot <== rc_forestMerkleRoot;
    zAccountRegistrationV1.taxiMerkleRoot <== rc_taxiMerkleRoot;
    zAccountRegistrationV1.busMerkleRoot <== rc_busMerkleRoot;
    zAccountRegistrationV1.ferryMerkleRoot <== rc_ferryMerkleRoot;

    zAccountRegistrationV1.salt <== rc_salt;
    zAccountRegistrationV1.saltHash <== rc_saltHash;

    zAccountRegistrationV1.magicalConstraint <== rc_magicalConstraint;
}
