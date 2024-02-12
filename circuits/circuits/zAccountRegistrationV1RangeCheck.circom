//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./templates/rangeCheck.circom";

template ZAccountRegistrationRangeCheck (ZNetworkMerkleTreeDepth,
                                         ZAssetMerkleTreeDepth,
                                         ZAccountBlackListMerkleTreeDepth,
                                         ZZoneMerkleTreeDepth,
                                         TrustProvidersMerkleTreeDepth) {

    signal input extraInputsHash;

    signal input zkpAmount;
    signal input zkpChange;

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

    signal input zAccountId;
    signal input zAccountZkpAmount;
    signal input zAccountPrpAmount;
    signal input zAccountZoneId;
    signal input zAccountNetworkId;
    signal input zAccountExpiryTime;
    signal input zAccountNonce;
    signal input zAccountTotalAmountPerTimePeriod;
    signal input zAccountCreateTime;
    signal input zAccountRootSpendPubKey[2];
    signal input zAccountReadPubKey[2];
    signal input zAccountNullifierPubKey[2];
    signal input zAccountMasterEOA;
    signal input zAccountRootSpendPrivKey;
    signal input zAccountReadPrivKey;
    signal input zAccountNullifierPrivKey;
    signal input zAccountSpendKeyRandom;
    signal input zAccountNullifier;
    signal input zAccountCommitment;

    signal input zAccountBlackListLeaf;
    signal input zAccountBlackListMerkleRoot;
    signal input zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth];

    signal input zZoneOriginZoneIDs;
    signal input zZoneTargetZoneIDs;
    signal input zZoneNetworkIDsBitMap;
    signal input zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input zZoneKycExpiryTime;
    signal input zZoneKytExpiryTime;
    signal input zZoneDepositMaxAmount;
    signal input zZoneWithrawMaxAmount;
    signal input zZoneInternalMaxAmount;
    signal input zZoneMerkleRoot;
    signal input zZonePathElements[ZZoneMerkleTreeDepth];
    signal input zZonePathIndices[ZZoneMerkleTreeDepth];
    signal input zZoneEdDsaPubKey[2];
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;

    signal input kycEdDsaPubKey[2];
    signal input kycEdDsaPubKeyExpiryTime;
    signal input trustProvidersMerkleRoot;
    signal input kycPathElements[TrustProvidersMerkleTreeDepth];
    signal input kycPathIndices[TrustProvidersMerkleTreeDepth];
    signal input kycMerkleTreeLeafIDsAndRulesOffset;

    signal input kycSignedMessagePackageType;
    signal input kycSignedMessageTimestamp;
    signal input kycSignedMessageSender;
    signal input kycSignedMessageReceiver;
    signal input kycSignedMessageSessionId;
    signal input kycSignedMessageRuleId;
    signal input kycSignedMessageSigner;
    signal input kycSignedMessageHash;
    signal input kycSignature[3];

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

    signal input staticTreeMerkleRoot;

    signal input forestMerkleRoot;
    signal input taxiMerkleRoot;
    signal input busMerkleRoot;
    signal input ferryMerkleRoot;

    signal input salt;
    signal input saltHash;

    signal input magicalConstraint;

    // extraInputsHash - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckExtraInputsHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckExtraInputsHash.in <== extraInputsHash;

    // zkpAmount - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZkpAmount.in <== zkpAmount;

    // zkpChange - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZkpChange = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZkpChange.in <== zkpChange;

    // zAssetId - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZAssetId = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAssetId.in <== zAssetId;

    // zAssetToken - 160 bits ERC20 token
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckZAssetToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAssetToken.in <== zAssetToken;

    // zAssetTokenId - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAssetTokenId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAssetTokenId.in <== zAssetTokenId;

    // zAssetNetwork - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZAssetNetwork = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetNetwork.in <== zAssetNetwork;

    // zAssetOffset - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZAssetOffset = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetOffset.in <== zAssetOffset;

    // zAssetWeight - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAssetWeight = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAssetWeight.in <== zAssetWeight;

    // zAssetScale - 7 bits
    // Supported range - [0 - (2**7 - 1)]
    component customRangeCheckZAssetScale = RangeCheckSingleSignal(7,(2**7 - 1),0);
    customRangeCheckZAssetScale.in <== zAssetScale;

    // zAssetMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree details - Checked as part of DApp and SC.
    // component customRangeCheckZAssetMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAssetMerkleRoot.in <== zAssetMerkleRoot;

    // zAssetPathIndices - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree details - Checked as part of DApp and SC.
    // component customRangeCheckZAssetPathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckZAssetPathIndices.in <== zAssetPathIndices;

    // zAssetPathElements - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree details - Checked as part of DApp and SC.
    // component customRangeCheckZAssetPathElements = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckZAssetPathElements.in <== zAssetPathElements;

    // zAccountId - 24 bits
    // circom supported bits - 2**24
    // Supported range - [0 - (2**24 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountId = RangeCheckSingleSignal(24, (2**24 - 1),0);
    // customRangeCheckZAccountId.in <== zAccountId;

    // zAccountZkpAmount - 252 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountZkpAmount.in <== zAccountZkpAmount;

    // zAccountPrpAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZAccountPrpAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAccountPrpAmount.in <== zAccountPrpAmount;

    // zAccountZoneId - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckZAccountZoneId = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountZoneId.in <== zAccountZoneId;

    // zAccountNetworkId - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZAccountNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAccountNetworkId.in <== zAccountNetworkId;

    // zAccountExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountExpiryTime.in <== zAccountExpiryTime;

    // zAccountNonce - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckZAccountNonce = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountNonce.in <== zAccountNonce;

    // zAccountTotalAmountPerTimePeriod - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountTotalAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountTotalAmountPerTimePeriod.in <== zAccountTotalAmountPerTimePeriod;

    // zAccountCreateTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountCreateTime.in <== zAccountCreateTime;

    // zAccountRootSpendPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountRootSpendPubKey = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    // customRangeCheckZAccountRootSpendPubKey.in <== zAccountRootSpendPubKey;

    // zAccountReadPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountReadPubKey = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    // customRangeCheckZAccountReadPubKey.in <== zAccountReadPubKey;

    // zAccountNullifierPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountNullifierPubKey = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    // customRangeCheckZAccountNullifierPubKey.in <== zAccountNullifierPubKey;

    // zAccountMasterEOA - 160 bits
    // Supported range - [0 - (2**160 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountMasterEOA = RangeCheckSingleSignal(160,(2**160 - 1),0);
    // customRangeCheckZAccountMasterEOA.in <== zAccountMasterEOA;

    // zAccountRootSpendPrivKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountRootSpendPrivKey = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountRootSpendPrivKey.in <== zAccountRootSpendPrivKey;

    // zAccountReadPrivKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountReadPrivKey = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountReadPrivKey.in <== zAccountReadPrivKey;

    // zAccountNullifierPrivKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountNullifierPrivKey = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountNullifierPrivKey.in <== zAccountNullifierPrivKey;

    // zAccountSpendKeyRandom - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountSpendKeyRandom = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountSpendKeyRandom.in <== zAccountSpendKeyRandom;

    // zAccountNullifier - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountNullifier = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAccountNullifier.in <== zAccountNullifier;

    // zAccountCommitment - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountCommitment = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAccountCommitment.in <== zAccountCommitment;

    // zAccountBlackListLeaf - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountBlackListLeaf = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountBlackListLeaf.in <== zAccountBlackListLeaf;

    // zAccountBlackListMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree details - Checked as part of DApp and SC.
    // component customRangeCheckZAccountBlackListMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAccountBlackListMerkleRoot.in <== zAccountBlackListMerkleRoot;

    // zAccountBlackListPathElements - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree details - Checked as part of DApp and SC.
    // component customRangeCheckZAccountBlackListPathElements = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckZAccountBlackListPathElements.in <== zAccountBlackListPathElements;

    // zZoneOriginZoneIDs - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneOriginZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneOriginZoneIDs.in <== zZoneOriginZoneIDs;

    // zZoneTargetZoneIDs - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneTargetZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneTargetZoneIDs.in <== zZoneTargetZoneIDs;

    // zZoneNetworkIDsBitMap - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZZoneNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneNetworkIDsBitMap.in <== zZoneNetworkIDsBitMap;

    // zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList.in <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;

    // zZoneKycExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZZoneKycExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneKycExpiryTime.in <== zZoneKycExpiryTime;

    // zZoneKytExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZZoneKytExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneKytExpiryTime.in <== zZoneKytExpiryTime;

    // zZoneDepositMaxAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZZoneDepositMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneDepositMaxAmount.in <== zZoneDepositMaxAmount;

    // zZoneWithrawMaxAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZZoneWithrawMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneWithrawMaxAmount.in <== zZoneWithrawMaxAmount;

    // zZoneInternalMaxAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZZoneInternalMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneInternalMaxAmount.in <== zZoneInternalMaxAmount;

    // zZoneMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree related details are range checked from DApp and SC.
    // component customRangeCheckZZoneMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZZoneMerkleRoot.in <== zZoneMerkleRoot;

    // zZonePathElements - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree related details are range checked from DApp and SC.
    // component customRangeCheckZZonePathElements = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckZZonePathElements.in <== zZonePathElements;

    // zZonePathIndices - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree related details are range checked from DApp and SC.
    // component customRangeCheckZZonePathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckZZonePathIndices.in <== zZonePathIndices;

    // zZoneEdDsaPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree related details are range checked from DApp and SC.
    // component customRangeCheckzZoneEdDsaPubKey = RangeCheckGroupOfSignals(2,252,(2**252 - 1),0);
    // customRangeCheckzZoneEdDsaPubKey.in <== zZoneEdDsaPubKey;

    // zZoneZAccountIDsBlackList - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneZAccountIDsBlackList = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneZAccountIDsBlackList.in <== zZoneZAccountIDsBlackList;

    // zZoneMaximumAmountPerTimePeriod - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneMaximumAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneMaximumAmountPerTimePeriod.in <== zZoneMaximumAmountPerTimePeriod;

    // zZoneTimePeriodPerMaximumAmount - 32 bit
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZZoneTimePeriodPerMaximumAmount = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneTimePeriodPerMaximumAmount.in <== zZoneTimePeriodPerMaximumAmount;

    // kycEdDsaPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckKycEdDsaPubKey = RangeCheckGroupOfSignals(2,252,(2**252 - 1),0);
    // customRangeCheckKycEdDsaPubKey.in <== kycEdDsaPubKey;

    // kycEdDsaPubKeyExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckKycEdDsaPubKeyExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckKycEdDsaPubKeyExpiryTime.in <== kycEdDsaPubKeyExpiryTime;

    // trustProvidersMerkleRoot - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckTrustProvidersMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckTrustProvidersMerkleRoot.in <== trustProvidersMerkleRoot;

    // kycPathElements - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckKycPathElements = RangeCheckGroupOfSignals(16,252,(2**252 - 1),0);
    // customRangeCheckKycPathElements.in <== kycPathElements;

    // kycPathIndices - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckKycPathIndices = RangeCheckGroupOfSignals(16,252,(2**252 - 1),0);
    // customRangeCheckKycPathIndices.in <== kycPathIndices;

    // kycMerkleTreeLeafIDsAndRulesOffset - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckKycMerkleTreeLeafIDsAndRulesOffset = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckKycMerkleTreeLeafIDsAndRulesOffset.in <== kycMerkleTreeLeafIDsAndRulesOffset;

    // kycSignedMessagePackageType - 8 bits
    // Supported range - [0 - (2**2 - 1)]
    component customRangeCheckKycSignedMessagePackageType = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheckKycSignedMessagePackageType.in <== kycSignedMessagePackageType;

    // kycSignedMessageTimestamp - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckKycSignedMessageTimestamp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckKycSignedMessageTimestamp.in <== kycSignedMessageTimestamp;

    // kycSignedMessageSender - 160 bits
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckKycSignedMessageSender = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKycSignedMessageSender.in <== kycSignedMessageSender;

    // kycSignedMessageReceiver - 160 bits
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckKycSignedMessageReceiver = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKycSignedMessageReceiver.in <== kycSignedMessageReceiver;

    // kycSignedMessageSessionId - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckKycSignedMessageSessionId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckKycSignedMessageSessionId.in <== kycSignedMessageSessionId;

    // kycSignedMessageRuleId - 8 bits
    // Supported range - [0 - (2**8 - 1)]
    component customRangeCheckKycSignedMessageRuleId = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheckKycSignedMessageRuleId.in <== kycSignedMessageRuleId;

    // kycSignedMessageSigner - 160 bits
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckKycSignedMessageSigner = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKycSignedMessageSigner.in <== kycSignedMessageSigner;

    // kycSignedMessageHash - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckKycSignedMessageHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckKycSignedMessageHash.in <== kycSignedMessageHash;

    // kycSignature - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckKycSignature = RangeCheckGroupOfSignals(3,252,(2**252 - 1),0);
    // customRangeCheckKycSignature.in <== kycSignature;

    // zNetworkId - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZNetworkId.in <== zNetworkId;

    // zNetworkChainId - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZNetworkChainId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZNetworkChainId.in <== zNetworkChainId;

    // zNetworkIDsBitMap - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZNetworkIDsBitMap.in <== zNetworkIDsBitMap;

    // zNetworkTreeMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckZNetworkTreeMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZNetworkTreeMerkleRoot.in <== zNetworkTreeMerkleRoot;

    // zNetworkTreePathElements - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckZNetworkTreePathElements = RangeCheckGroupOfSignals(6, 252,(2**252 - 1),0);
    // customRangeCheckZNetworkTreePathElements.in <== zNetworkTreePathElements;

    // zNetworkTreePathIndices - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckZNetworkTreePathIndices = RangeCheckGroupOfSignals(6, 252,(2**252 - 1),0);
    // customRangeCheckZNetworkTreePathIndices.in <== zNetworkTreePathIndices;

    // daoDataEscrowPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckDaoDataEscrowPubKey = RangeCheckGroupOfSignals(2,252,(2**252 - 1),0);
    // customRangeCheckDaoDataEscrowPubKey.in <== daoDataEscrowPubKey;

    // forTxReward - 40 bits
    // Supported range - [0 - (2**40 - 1)]
    component customRangeCheckForTxReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForTxReward.in <== forTxReward;

    // forUtxoReward - 40 bits
    // Supported range - [0 - (2**40 - 1)]
    component customRangeCheckForUtxoReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForUtxoReward.in <== forUtxoReward;

    // forDepositReward - 40 bits
    // Supported range - [0 - (2**40 - 1)]
    component customRangeCheckForDepositReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForDepositReward.in <== forDepositReward;

    // staticTreeMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckForStaticTreeMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForStaticTreeMerkleRoot.in <== staticTreeMerkleRoot;

    // forestMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckForForestMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForForestMerkleRoot.in <== forestMerkleRoot;

    // taxiMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckForTaxiMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForTaxiMerkleRoot.in <== taxiMerkleRoot;

    // busMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckForBusMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForBusMerkleRoot.in <== busMerkleRoot;

    // ferryMerkleRoot - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckForFerryMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForFerryMerkleRoot.in <== ferryMerkleRoot;

    // salt - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckForSalt = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckForSalt.in <== salt;

    // saltHash - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckForSaltHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForSaltHash.in <== saltHash;

    // magicalConstraint - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckForMagicalConstraint = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckForMagicalConstraint.in <== magicalConstraint;
}
