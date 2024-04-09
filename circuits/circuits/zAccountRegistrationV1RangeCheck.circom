//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./templates/rangeCheck.circom";

template ZAccountRegistrationRangeCheck (ZNetworkMerkleTreeDepth,
                                         ZAssetMerkleTreeDepth,
                                         ZAccountBlackListMerkleTreeDepth,
                                         ZZoneMerkleTreeDepth,
                                         TrustProvidersMerkleTreeDepth) {

    signal input extraInputsHash;

    signal input addedAmountZkp;
    signal input chargedAmountZkp;

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

    //////////////////////////////////////////////////////////////////////////////////////////////
    // Format of comments:
        // Field name - Size of the field
        // Public Signal?
        // Maximum supported range | Within SNARK FIELD (254 bits) | Within Suborder
        // Should it be checked in SC?

    // SNARK FIELD SIZE - 21888242871839275222246405745257275088548364400416034343698204186575808495617
    //////////////////////////////////////////////////////////////////////////////////////////////

    // extraInputsHash - 256 bits 
    // Public signal
    // Must be within the SNARK_FIELD
    // Must be checked as part of SC

    // addedAmountZkp - 252 bits
    // Public signal
    // Supported range - [0 to (2**252 - 1)]
    // Must be checked as part of SC
    component customRangeCheckDonatedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckDonatedAmountZkp.in <== addedAmountZkp;

    // chargedAmountZkp - 252 bits
    // Public signal
    // Supported range - [0 - (2**252 - 1)]
    // Must be checked as part of SC
    component customRangeCheckChargedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckChargedAmountZkp.in <== chargedAmountZkp;

    // zAssetId - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZAssetId = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAssetId.in <== zAssetId;

    // zAssetToken - 160 bits ERC20 token
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckZAssetToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAssetToken.in <== zAssetToken;

    // zAssetTokenId - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Must be checked from SC end

    // zAssetNetwork - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZAssetNetwork = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetNetwork.in <== zAssetNetwork;

    // zAssetOffset - 6 bits
    // Supported range - [0 - 32]
    // Although it is a 6 bits field, maximum value that it should be constrained to is 32.
    component customRangeCheckZAssetOffset = RangeCheckSingleSignal(6,32,0);
    customRangeCheckZAssetOffset.in <== zAssetOffset;

    // zAssetWeight - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAssetWeight = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAssetWeight.in <== zAssetWeight;

    // zAssetScale - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    component customRangeCheckZAssetScale = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAssetScale.in <== zAssetScale;

    // zAssetMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAssetPathIndices
    // ToDo - Path Indices should be fixed to 1 bit?
    component customRangeCheckZAssetPathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    customRangeCheckZAssetPathIndices.in <== zAssetPathIndices;

    // zAssetPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountId - 24 bits
    // Public signal
    // Supported range - [0 - (2**24 - 1)]
    // Must be checked as part of SC
    component customRangeCheckZAccountId = RangeCheckSingleSignal(24, (2**24 - 1),0);
    customRangeCheckZAccountId.in <== zAccountId;

    // zAccountZkpAmount - 252 bits
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
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountTotalAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountTotalAmountPerTimePeriod.in <== zAccountTotalAmountPerTimePeriod;

    // zAccountCreateTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountCreateTime.in <== zAccountCreateTime;

    // zAccountRootSpendPubKey - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountReadPubKey - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountNullifierPubKey - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountMasterEOA - 160 bits
    // Public signal
    // Supported range - [0 - (2**160 - 1)]
    // Should be checked as part of the SC
    component customRangeCheckZAccountMasterEOA = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAccountMasterEOA.in <== zAccountMasterEOA;

    // zAccountRootSpendPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountReadPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountNullifierPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountSpendKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountNullifier
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountCommitment 
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListLeaf - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountBlackListLeaf = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountBlackListLeaf.in <== zAccountBlackListLeaf;

    // zAccountBlackListMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC


    // zAccountBlackListPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZoneOriginZoneIDs - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneOriginZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneOriginZoneIDs.in <== zZoneOriginZoneIDs;

    // zZoneTargetZoneIDs - 256 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneTargetZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneTargetZoneIDs.in <== zZoneTargetZoneIDs;

    // zZoneNetworkIDsBitMap - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZZoneNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneNetworkIDsBitMap.in <== zZoneNetworkIDsBitMap;

    // zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList - 240 bits
    // circom supported bits - 2**240
    // Supported range - [0 - (2**240 - 1)]
    component customRangeCheckZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList = RangeCheckSingleSignal(240,(2**240 - 1),0);
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
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZonePathElements - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZonePathIndices
    // ToDo - should be changed to 1 bit

    // zZoneEdDsaPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneZAccountIDsBlackList - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // ToDo - Should we restrict to 252?
    component customRangeCheckZZoneZAccountIDsBlackList = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneZAccountIDsBlackList.in <== zZoneZAccountIDsBlackList;

    // zZoneMaximumAmountPerTimePeriod - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    component customRangeCheckZZoneMaximumAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneMaximumAmountPerTimePeriod.in <== zZoneMaximumAmountPerTimePeriod;

    // zZoneTimePeriodPerMaximumAmount - 32 bit
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZZoneTimePeriodPerMaximumAmount = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneTimePeriodPerMaximumAmount.in <== zZoneTimePeriodPerMaximumAmount;

    // kycEdDsaPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // kycEdDsaPubKeyExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckKycEdDsaPubKeyExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckKycEdDsaPubKeyExpiryTime.in <== kycEdDsaPubKeyExpiryTime;

    // trustProvidersMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kycPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kycPathIndices - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Needs to check 1 bit?
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
    // Todo - Should it be checked from SC?
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

    // kycSignedMessageHash 
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kycSignature
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkId - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZNetworkId.in <== zNetworkId;

    // zNetworkChainId - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zNetworkIDsBitMap - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZNetworkIDsBitMap.in <== zNetworkIDsBitMap;

    // zNetworkTreeMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkTreePathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkTreePathIndices - 256 bits
    // ToDo - Must be restricted to binary?
    // component customRangeCheckZNetworkTreePathIndices = RangeCheckGroupOfSignals(6, 252,(2**252 - 1),0);
    // customRangeCheckZNetworkTreePathIndices.in <== zNetworkTreePathIndices;

    // daoDataEscrowPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

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
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // forestMerkleRoot - 256 bits
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // taxiMerkleRoot - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // busMerkleRoot - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // ferryMerkleRoot - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // salt - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // saltHash 
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // magicalConstraint - 256 bits
    // Public signal
    // Should be checked as part of the SC
}
