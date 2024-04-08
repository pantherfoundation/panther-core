//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./templates/rangeCheck.circom";

template ZAccountRenewalRangeCheck (UtxoLeftMerkleTreeDepth,
                                         UtxoMiddleMerkleTreeDepth,
                                         ZNetworkMerkleTreeDepth,
                                         ZAssetMerkleTreeDepth,
                                         ZAccountBlackListMerkleTreeDepth,
                                         ZZoneMerkleTreeDepth,
                                         TrustProvidersMerkleTreeDepth) {

    var UtxoRightMerkleTreeDepth = UtxoMiddleMerkleTreeDepth + ZNetworkMerkleTreeDepth;
    var UtxoMerkleTreeDepth = UtxoRightMerkleTreeDepth;

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
    signal input zAssetPathIndices[ZAssetMerkleTreeDepth]; // Is 252 needed?
    signal input zAssetPathElements[ZAssetMerkleTreeDepth];

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
    signal input zAccountUtxoInCommitment;
    signal input zAccountUtxoInNullifier;
    signal input zAccountUtxoInMerkleTreeSelector[2];
    signal input zAccountUtxoInPathIndices[UtxoMerkleTreeDepth]; // Is 252 needed?
    signal input zAccountUtxoInPathElements[UtxoMerkleTreeDepth];

    signal input zAccountUtxoOutZkpAmount;
    signal input zAccountUtxoOutExpiryTime;
    signal input zAccountUtxoOutCreateTime;
    signal input zAccountUtxoOutSpendKeyRandom;
    signal input zAccountUtxoOutCommitment;

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
    signal input zZonePathIndices[ZZoneMerkleTreeDepth]; // Is 252 needed?
    signal input zZoneEdDsaPubKey[2];
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;

    signal input kycEdDsaPubKey[2];
    signal input kycEdDsaPubKeyExpiryTime;
    signal input trustProvidersMerkleRoot;
    signal input kycPathElements[TrustProvidersMerkleTreeDepth];
    signal input kycPathIndices[TrustProvidersMerkleTreeDepth]; // Is 252 needed?
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
    signal input zNetworkTreePathIndices[ZNetworkMerkleTreeDepth]; // Is 252 needed?

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
    component customRangeCheckExtraInputsHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckExtraInputsHash.in <== extraInputsHash;

    // addedAmountZkp - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckDonatedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckDonatedAmountZkp.in <== addedAmountZkp;

    // chargedAmountZkp - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
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

    // zAssetScale - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAssetScale = RangeCheckSingleSignal(252,(2**252 - 1),0);
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

    // zAccountUtxoInId AKA zAccountId - 24 bits
    // circom supported bits - 2**24
    // Supported range - [0 - (2**24 - 1)]
    component customRangeCheckZAccountUtxoInId = RangeCheckSingleSignal(24, (2**24 - 1),0);
    customRangeCheckZAccountUtxoInId.in <== zAccountUtxoInId;

    // zAccountUtxoInZkpAmount AKA zAccountZkpAmount - 252 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInZkpAmount.in <== zAccountUtxoInZkpAmount;

    // zAccountUtxoInPrpAmount AKA zAccountPrpAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZAccountUtxoInPrpAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAccountUtxoInPrpAmount.in <== zAccountUtxoInPrpAmount;

    // zAccountUtxoInZoneId AKA zAccountZoneId - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckZAccountUtxoInZoneId = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountUtxoInZoneId.in <== zAccountUtxoInZoneId;

    // zAccountUtxoInNetworkId AKA zAccountNetworkId - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckzAccountUtxoInNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckzAccountUtxoInNetworkId.in <== zAccountUtxoInNetworkId;

    // zAccountUtxoInExpiryTime AKA zAccountExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountUtxoInExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountUtxoInExpiryTime.in <== zAccountUtxoInExpiryTime;

    // zAccountUtxoInNonce AKA zAccountNonce - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckZAccountUtxoInNonce = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountUtxoInNonce.in <== zAccountUtxoInNonce;

    // zAccountUtxoInTotalAmountPerTimePeriod AKA zAccountTotalAmountPerTimePeriod - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInTotalAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInTotalAmountPerTimePeriod.in <== zAccountUtxoInTotalAmountPerTimePeriod;

    // zAccountUtxoInCreateTime AKA zAccountCreateTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountUtxoInCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountUtxoInCreateTime.in <== zAccountUtxoInCreateTime;

    // zAccountUtxoInRootSpendPrivKey AKA zAccountRootSpendPrivKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInRootSpendPrivKey = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInRootSpendPrivKey.in <== zAccountUtxoInRootSpendPrivKey;

    // zAccountUtxoInRootSpendPubKey AKA zAccountRootSpendPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckZAccountUtxoInRootSpendPubKey = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoInRootSpendPubKey.in <== zAccountUtxoInRootSpendPubKey;

    // zAccountUtxoInReadPubKey AKA zAccountReadPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInReadPubKey = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInReadPubKey.in <== zAccountUtxoInReadPubKey;

    // zAccountUtxoInNullifierPubKey AKA zAccountNullifierPubKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // component customRangeCheckZAccountUtxoInNullifierPubKey = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoInNullifierPubKey.in <== zAccountUtxoInNullifierPubKey;

    // zAccountUtxoInMasterEOA AKA zAccountMasterEOA - 160 bits
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckZAccountUtxoInMasterEOA = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAccountUtxoInMasterEOA.in <== zAccountUtxoInMasterEOA;

    // zAccountUtxoInSpendKeyRandom
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountSpendKeyRandom = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountSpendKeyRandom.in <== zAccountUtxoInSpendKeyRandom;

    // zAccountUtxoInNullifierPrivKey AKA zAccountNullifierPrivKey - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInNullifierPrivKey = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInNullifierPrivKey.in <== zAccountUtxoInNullifierPrivKey;

    // zAccountUtxoInCommitment AKA zAccountCommitment - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountUtxoInCommitment = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoInCommitment.in <== zAccountUtxoInCommitment;

    // zAccountUtxoInNullifier AKA zAccountNullifier - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountUtxoInNullifier = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoInNullifier.in <== zAccountUtxoInNullifier;

    // zAccountUtxoInMerkleTreeSelector
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInMerkleTreeSelector = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInMerkleTreeSelector.in <== zAccountUtxoInMerkleTreeSelector;

    // zAccountUtxoInPathIndices - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree related details are range checked from DApp and SC.
    // component customRangeCheckZAccountUtxoInPathIndices = RangeCheckGroupOfSignals(32, 252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoInPathIndices.in <== zAccountUtxoInPathIndices;

    // zAccountUtxoInPathElements - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Merkle Tree related details are range checked from DApp and SC.
    // component customRangeCheckZAccountUtxoInPathElements = RangeCheckGroupOfSignals(32, 252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoInPathElements.in <== zAccountUtxoInPathElements;

    // zAccountUtxoOutZkpAmount - 252 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoOutZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoOutZkpAmount.in <== zAccountUtxoOutZkpAmount;

    // zAccountUtxoOutExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountUtxoOutExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountUtxoOutExpiryTime.in <== zAccountUtxoOutExpiryTime;

    // zAccountUtxoOutCreateTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckZAccountUtxoOutCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountUtxoOutCreateTime.in <== zAccountUtxoOutCreateTime;

    // zAccountUtxoOutSpendKeyRandom
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoOutSpendKeyRandom = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoOutSpendKeyRandom.in <== zAccountUtxoOutSpendKeyRandom;

    // zAccountUtxoOutCommitment - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    // component customRangeCheckZAccountUtxoOutCommitment = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZAccountUtxoOutCommitment.in <== zAccountUtxoOutCommitment;

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
    component customRangeCheckzZoneEdDsaPubKey = RangeCheckGroupOfSignals(2,252,(2**252 - 1),0);
    customRangeCheckzZoneEdDsaPubKey.in <== zZoneEdDsaPubKey;

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
    component customRangeCheckKycPathIndices = RangeCheckGroupOfSignals(16,252,(2**252 - 1),0);
    customRangeCheckKycPathIndices.in <== kycPathIndices;

    // kycMerkleTreeLeafIDsAndRulesOffset - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckKycMerkleTreeLeafIDsAndRulesOffset = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckKycMerkleTreeLeafIDsAndRulesOffset.in <== kycMerkleTreeLeafIDsAndRulesOffset;

    // kycSignedMessagePackageType - 8 bits
    // Supported range - [0 - (2**8 - 1)]
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
    component customRangeCheckKycSignedMessageHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckKycSignedMessageHash.in <== kycSignedMessageHash;

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
    component customRangeCheckForStaticTreeMerkleRoot = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckForStaticTreeMerkleRoot.in <== staticTreeMerkleRoot;

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
    component customRangeCheckForSaltHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckForSaltHash.in <== saltHash;

    // magicalConstraint - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckForMagicalConstraint = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckForMagicalConstraint.in <== magicalConstraint;
}
