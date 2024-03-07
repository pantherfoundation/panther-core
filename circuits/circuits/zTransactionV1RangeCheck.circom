//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./templates/rangeCheck.circom"; 

template ZTransactionV1RangeCheck( nUtxoIn,
                                   nUtxoOut,
                                   UtxoLeftMerkleTreeDepth,
                                   UtxoMiddleMerkleTreeDepth,
                                   ZNetworkMerkleTreeDepth,
                                   ZAssetMerkleTreeDepth,
                                   ZAccountBlackListMerkleTreeDepth,
                                   ZZoneMerkleTreeDepth,
                                   TrustProvidersMerkleTreeDepth ) {
    //////////////////////////////////////////////////////////////////////////////////////////////
    // Ferry MT size
    var UtxoRightMerkleTreeDepth = UtxoMiddleMerkleTreeDepth + ZNetworkMerkleTreeDepth;
    // Equal to ferry MT size
    var UtxoMerkleTreeDepth = UtxoRightMerkleTreeDepth;
    // Bus MT extra levels
    var UtxoMiddleExtraLevels = UtxoMiddleMerkleTreeDepth - UtxoLeftMerkleTreeDepth;
    // Ferry MT extra levels
    var UtxoRightExtraLevels = UtxoRightMerkleTreeDepth - UtxoMiddleMerkleTreeDepth;
    //////////////////////////////////////////////////////////////////////////////////////////////
    signal input extraInputsHash;

    signal input depositAmount;
    signal input depositChange;

    signal input withdrawAmount;
    signal input withdrawChange;
    signal input donatedAmountZkp;
    signal input token;
    signal input tokenId;
    signal input utxoZAsset;

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

    signal input zAssetIdZkp;
    signal input zAssetTokenZkp;
    signal input zAssetTokenIdZkp;
    signal input zAssetNetworkZkp;
    signal input zAssetOffsetZkp;
    signal input zAssetWeightZkp;
    signal input zAssetScaleZkp;
    signal input zAssetPathIndicesZkp[ZAssetMerkleTreeDepth];
    signal input zAssetPathElementsZkp[ZAssetMerkleTreeDepth];

    signal input forTxReward;
    signal input forUtxoReward;
    signal input forDepositReward;

    signal input spendTime;

    signal input utxoInSpendPrivKey[nUtxoIn];
    signal input utxoInSpendKeyRandom[nUtxoIn];
    signal input utxoInAmount[nUtxoIn];
    signal input utxoInOriginZoneId[nUtxoIn];
    signal input utxoInOriginZoneIdOffset[nUtxoIn];
    signal input utxoInOriginNetworkId[nUtxoIn];
    signal input utxoInTargetNetworkId[nUtxoIn];
    signal input utxoInCreateTime[nUtxoIn];
    signal input utxoInZAccountId[nUtxoIn];
    signal input utxoInMerkleTreeSelector[nUtxoIn][2];
    signal input utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth];
    signal input utxoInPathElements[nUtxoIn][UtxoMerkleTreeDepth];
    signal input utxoInNullifier[nUtxoIn];

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
    signal input zAccountUtxoInMasterEOA;
    signal input zAccountUtxoInSpendPrivKey;
    signal input zAccountUtxoInReadPrivKey;
    signal input zAccountUtxoInNullifierPrivKey;
    signal input zAccountUtxoInMerkleTreeSelector[2];
    signal input zAccountUtxoInPathIndices[UtxoMerkleTreeDepth];
    signal input zAccountUtxoInPathElements[UtxoMerkleTreeDepth];
    signal input zAccountUtxoInNullifier;

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
    signal input zZoneDataEscrowEphimeralRandom;
    signal input zZoneDataEscrowEphimeralPubKeyAx;
    signal input zZoneDataEscrowEphimeralPubKeyAy;
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;

    var zZoneDataEscrowScalarSize = 1;
    var zZoneDataEscrowEncryptedPoints = zZoneDataEscrowScalarSize;
    signal input zZoneDataEscrowEncryptedMessageAx[zZoneDataEscrowEncryptedPoints];
    signal input zZoneDataEscrowEncryptedMessageAy[zZoneDataEscrowEncryptedPoints];

    signal input kytEdDsaPubKey[2];
    signal input kytEdDsaPubKeyExpiryTime;
    signal input trustProvidersMerkleRoot;
    signal input kytPathElements[TrustProvidersMerkleTreeDepth];
    signal input kytPathIndices[TrustProvidersMerkleTreeDepth];
    signal input kytMerkleTreeLeafIDsAndRulesOffset;

    signal input kytDepositSignedMessagePackageType;
    signal input kytDepositSignedMessageTimestamp;
    signal input kytDepositSignedMessageSender;
    signal input kytDepositSignedMessageReceiver;
    signal input kytDepositSignedMessageToken;
    signal input kytDepositSignedMessageSessionId;
    signal input kytDepositSignedMessageRuleId;
    signal input kytDepositSignedMessageAmount;
    signal input kytDepositSignedMessageSigner;
    signal input kytDepositSignedMessageHash;
    signal input kytDepositSignature[3];

    signal input kytWithdrawSignedMessagePackageType;
    signal input kytWithdrawSignedMessageTimestamp;
    signal input kytWithdrawSignedMessageSender;
    signal input kytWithdrawSignedMessageReceiver;
    signal input kytWithdrawSignedMessageToken;
    signal input kytWithdrawSignedMessageSessionId;
    signal input kytWithdrawSignedMessageRuleId;
    signal input kytWithdrawSignedMessageAmount;
    signal input kytWithdrawSignedMessageSigner;
    signal input kytWithdrawSignedMessageHash;
    signal input kytWithdrawSignature[3];

    // data escrow
    signal input dataEscrowPubKey[2];
    signal input dataEscrowPubKeyExpiryTime;
    signal input dataEscrowEphimeralRandom;
    signal input dataEscrowEphimeralPubKeyAx;
    signal input dataEscrowEphimeralPubKeyAy;
    signal input dataEscrowPathElements[TrustProvidersMerkleTreeDepth];
    signal input dataEscrowPathIndices[TrustProvidersMerkleTreeDepth];

    var max_nUtxoIn_nUtxoOut = nUtxoIn > nUtxoOut ? nUtxoIn:nUtxoOut;
    var dataEscrowScalarSize = 1+1+nUtxoIn+nUtxoOut+max_nUtxoIn_nUtxoOut;
    var dataEscrowPointSize = nUtxoOut;
    var dataEscrowEncryptedPoints = dataEscrowScalarSize + dataEscrowPointSize;
    signal input dataEscrowEncryptedMessageAx[dataEscrowEncryptedPoints];
    signal input dataEscrowEncryptedMessageAy[dataEscrowEncryptedPoints];

    signal input daoDataEscrowPubKey[2];
    signal input daoDataEscrowEphimeralRandom;
    signal input daoDataEscrowEphimeralPubKeyAx;
    signal input daoDataEscrowEphimeralPubKeyAy;

    var daoDataEscrowScalarSize = 1 + max_nUtxoIn_nUtxoOut;
    var daoDataEscrowEncryptedPoints = daoDataEscrowScalarSize;
    signal input daoDataEscrowEncryptedMessageAx[daoDataEscrowEncryptedPoints];
    signal input daoDataEscrowEncryptedMessageAy[daoDataEscrowEncryptedPoints];

    signal input utxoOutCreateTime;
    signal input utxoOutAmount[nUtxoOut];
    signal input utxoOutOriginNetworkId[nUtxoOut];
    signal input utxoOutTargetNetworkId[nUtxoOut];
    signal input utxoOutTargetZoneId[nUtxoOut];
    signal input utxoOutTargetZoneIdOffset[nUtxoOut];
    signal input utxoOutSpendPubKeyRandom[nUtxoOut];
    signal input utxoOutRootSpendPubKey[nUtxoOut][2];
    signal input utxoOutCommitment[nUtxoOut];

    signal input zAccountUtxoOutZkpAmount;
    signal input zAccountUtxoOutSpendKeyRandom;
    signal input zAccountUtxoOutCommitment;

    signal input chargedAmountZkp;

    signal input zNetworkId;
    signal input zNetworkChainId;
    signal input zNetworkIDsBitMap;
    signal input zNetworkTreeMerkleRoot;
    signal input zNetworkTreePathElements[ZNetworkMerkleTreeDepth];
    signal input zNetworkTreePathIndices[ZNetworkMerkleTreeDepth];

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

    // depositAmount - 252 bits
    // Public signal
    // Supported range - [0 to (2**252 - 1)]
    // Todo - Can be restrcited to be 250 bits?
    component customRangeCheckDepositAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckDepositAmount.in <== depositAmount;

    // depositChange - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restrcited to be 250 bits?
    component customRangeCheckDepositChange = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckDepositChange.in <== depositChange;
    
    // withdrawAmount  - 252 bits
    // Public signal
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restrcited to be 250 bits?
    component customRangeCheckWithdrawAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckWithdrawAmount.in <== withdrawAmount;

    // withdrawChange - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restrcited to be 250 bits?
    component customRangeCheckWithdrawChange = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckWithdrawChange.in <== withdrawChange;

    // donatedAmountZkp - 252 bits
    // Public signal
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restrcited to be 250 bits?
    component customRangeCheckDonatedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckDonatedAmountZkp.in <== donatedAmountZkp;

    // token - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckToken.in <== token;

    // tokenId - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Must be checked from SC end.

    // utxoZAsset - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckUtxoZAsset = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckUtxoZAsset.in <== utxoZAsset;

    // zAssetId - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZAssetId = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAssetId.in <== zAssetId;

    // zAssetToken - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckZAssetToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAssetToken.in <== zAssetToken;

    // zAssetTokenId - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Must be checked from SC end

    // zAssetNetwork - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckZAssetNetwork = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetNetwork.in <== zAssetNetwork;

    // zAssetOffset - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckZAssetOffset = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetOffset.in <== zAssetOffset;

    // zAssetWeight - 32 bits
    // Supported range - [0 to (2**32 - 1)]
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

    // zAssetIdZkp - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZAssetIdZkp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAssetIdZkp.in <== zAssetIdZkp;

    // zAssetTokenZkp - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckZAssetTokenZkp = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAssetTokenZkp.in <== zAssetTokenZkp;

    // zAssetTokenIdZkp - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Must be checked from SC end

    // zAssetNetworkZkp - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckZAssetNetworkZkp = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetNetworkZkp.in <== zAssetNetworkZkp;

    // zAssetOffsetZkp - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckZAssetOffsetZkp = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAssetOffsetZkp.in <== zAssetOffsetZkp;

    // zAssetWeightZkp - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckZAssetWeightZkp = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAssetWeightZkp.in <== zAssetWeightZkp;

    // zAssetScaleZkp - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    component customRangeCheckZAssetScaleZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAssetScaleZkp.in <== zAssetScaleZkp;

    // zAssetPathIndicesZkp
    // ToDo - Path Indices should be fixed to 1 bit
    // component customRangeCheckZAssetPathIndicesZkp = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckZAssetPathIndicesZkp.in <== zAssetPathIndicesZkp;

    // zAssetPathElementsZkp 
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // forTxReward - 40 bits
    // Supported range - [0 to (2**40 - 1)]
    component customRangeCheckForTxReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForTxReward.in <== forTxReward;

    // forUtxoReward - 40 bits
    // Supported range - [0 to (2**40 - 1)]
    component customRangeCheckForUtxoReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForUtxoReward.in <== forUtxoReward;

    // forDepositReward - 40 bits
    // Supported range - [0 to (2**40 - 1)]
    component customRangeCheckForDepositReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForDepositReward.in <== forDepositReward;

    // spendTime - 32 bits
    // Public signal
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckForSpendTime = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheckForSpendTime.in <== spendTime;

    // utxoInSpendPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // utxoInSpendKeyRandom
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Must be checked from SC end

    // utxoInAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restrcited to be 250 bits?
    component customRangeCheckUtxoInAmount = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0); 
    customRangeCheckUtxoInAmount.in <== utxoInAmount;

    // utxoInOriginZoneId - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheckUtxoInOriginZoneId = RangeCheckGroupOfSignals(2, 16,(2**16 - 1),0); 
    customRangeCheckUtxoInOriginZoneId.in <== utxoInOriginZoneId;

    // utxoInOriginZoneIdOffset - 4 bits
    // Supported range - [0 to (2**4 - 1)]
    component customRangeCheckUtxoInOriginZoneIdOffset = RangeCheckGroupOfSignals(2, 4,(2**4 - 1),0); 
    customRangeCheckUtxoInOriginZoneIdOffset.in <== utxoInOriginZoneIdOffset;

    // utxoInOriginNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckUtxoInOriginNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0); 
    customRangeCheckUtxoInOriginNetworkId.in <== utxoInOriginNetworkId;

    // utxoInTargetNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckUtxoInTargetNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0); 
    customRangeCheckUtxoInTargetNetworkId.in <== utxoInTargetNetworkId;

    // utxoInCreateTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckUtxoInCreateTime = RangeCheckGroupOfSignals(2, 32,(2**32 - 1),0); 
    customRangeCheckUtxoInCreateTime.in <== utxoInCreateTime;

    // utxoInZAccountId - 24 bits
    // Supported range - [0 to (2**24 - 1)]
    component customRangeCheckUtxoInZAccountId = RangeCheckGroupOfSignals(2, 24,(2**24 - 1),0); 
    customRangeCheckUtxoInZAccountId.in <== utxoInZAccountId;

    // utxoInMerkleTreeSelector - 2 bits
    // ToDo - bit size is 2 bits
    component customRangeCheckUtxoInMerkleTreeSelectorUtxo0 = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheckUtxoInMerkleTreeSelectorUtxo0.in <== utxoInMerkleTreeSelector[0];

    component customRangeCheckUtxoInMerkleTreeSelectorUtxo1 = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheckUtxoInMerkleTreeSelectorUtxo1.in <== utxoInMerkleTreeSelector[1];

    // utxoInPathIndices
    // ToDo - Path Indices should be fixed to 1 bit
    // component customRangeCheckUtxoInPathIndices = RangeCheckGroupOfSignals(32, 252,(2**252 - 1),0);
    // customRangeCheckUtxoInPathIndices.in <== utxoInPathIndices[0];

    // utxoInPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // utxoInNullifier
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoInId - 24 bits
    // Supported range - [0 to (2**24 - 1)]
    component customRangeCheckZAccountUtxoInId = RangeCheckSingleSignal(24,(2**24 - 1),0); 
    customRangeCheckZAccountUtxoInId.in <== zAccountUtxoInId;

    // zAccountUtxoInZkpAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - cross verify if it is 64 bits?
    component customRangeCheckZAccountUtxoInZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0); 
    customRangeCheckZAccountUtxoInZkpAmount.in <== zAccountUtxoInZkpAmount;

    // zAccountUtxoInPrpAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZAccountUtxoInPrpAmount = RangeCheckSingleSignal(64,(2**64 - 1),0); 
    customRangeCheckZAccountUtxoInPrpAmount.in <== zAccountUtxoInPrpAmount;

    // zAccountUtxoInZoneId - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheckZAccountUtxoInZoneId = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountUtxoInZoneId.in <== zAccountUtxoInZoneId;

    // zAccountUtxoInNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckZAccountUtxoInNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0); 
    customRangeCheckZAccountUtxoInNetworkId.in <== zAccountUtxoInNetworkId;

    // zAccountUtxoInExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)] 
    component customRangeCheckZAccountUtxoInExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0); 
    customRangeCheckZAccountUtxoInExpiryTime.in <== zAccountUtxoInExpiryTime;

    // zAccountUtxoInNonce - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    // ToDo - check if this should be constrained or not?
    component customRangeCheckZAccountUtxoInNonce = RangeCheckSingleSignal(16,(2**16 - 1),0); 
    customRangeCheckZAccountUtxoInNonce.in <== zAccountUtxoInNonce;

    // zAccountUtxoInTotalAmountPerTimePeriod - 256 bits
    // ToDo - should we constraint it to 252?
    component customRangeCheckZAccountUtxoInTotalAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0); 
    customRangeCheckZAccountUtxoInTotalAmountPerTimePeriod.in <== zAccountUtxoInTotalAmountPerTimePeriod;

    // zAccountUtxoInCreateTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckZAccountUtxoInCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0); 
    customRangeCheckZAccountUtxoInCreateTime.in <== zAccountUtxoInCreateTime;

    // zAccountUtxoInRootSpendPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    
    // zAccountUtxoInReadPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoInNullifierPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoInMasterEOA - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckZAccountUtxoInMasterEOA = RangeCheckSingleSignal(160,(2**160 - 1),0); 
    customRangeCheckZAccountUtxoInMasterEOA.in <== zAccountUtxoInMasterEOA;

    // zAccountUtxoInSpendPrivKey 
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInReadPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInNullifierPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInMerkleTreeSelector - 2 bits
    // Supported range - [0 to (2**2 - 1)]
    component customRangeCheckZAccountUtxoInMerkleTreeSelector = RangeCheckGroupOfSignals(2, 2, (2**2 - 1), 0);
    customRangeCheckZAccountUtxoInMerkleTreeSelector.in <== zAccountUtxoInMerkleTreeSelector;

    // zAccountUtxoInPathIndices
    // ToDo - Path Indices should be fixed to 1 bit
    // component customRangeCheckZAccountUtxoInPathIndices = RangeCheckGroupOfSignals(32, 252, (2**252 - 1), 0);
    // customRangeCheckZAccountUtxoInPathIndices.in <== zAccountUtxoInPathIndices;

    // zAccountUtxoInPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoInNullifier
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListLeaf - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - should we restrict to 252?
    component customRangeCheckZAccountBlackListLeaf = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountBlackListLeaf.in <== zAccountBlackListLeaf;

    // zAccountBlackListMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZoneOriginZoneIDs - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - check if this needs to be restricted to 252 bit?
    component customRangeCheckZZoneOriginZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneOriginZoneIDs.in <== zZoneOriginZoneIDs;

    // zZoneTargetZoneIDs - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - check if this needs to be restricted to 252 bits?
    component customRangeCheckZZoneTargetZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneTargetZoneIDs.in <== zZoneTargetZoneIDs;

    // zZoneNetworkIDsBitMap - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZZoneNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneNetworkIDsBitMap.in <== zZoneNetworkIDsBitMap;

    // zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Constaint till only 240.
    component customRangeCheckZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList.in <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;

    // zZoneKycExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckZZoneKycExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneKycExpiryTime.in <== zZoneKycExpiryTime;

    // zZoneKytExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckZZoneKytExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneKytExpiryTime.in <== zZoneKytExpiryTime;

    // zZoneDepositMaxAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZZoneDepositMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneDepositMaxAmount.in <== zZoneDepositMaxAmount;

    // zZoneWithrawMaxAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZZoneWithrawMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneWithrawMaxAmount.in <== zZoneWithrawMaxAmount;

    // zZoneInternalMaxAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckZZoneInternalMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneInternalMaxAmount.in <== zZoneInternalMaxAmount;

    // zZoneMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZonePathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZonePathIndices 
    // ToDo - should be changed to 1 bit

    // zZoneEdDsaPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneDataEscrowEphimeralRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneDataEscrowEphimeralPubKeyAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneDataEscrowEphimeralPubKeyAy - 256 bits
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
    // component customRangeCheckZZoneMaximumAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckZZoneMaximumAmountPerTimePeriod.in <== zZoneMaximumAmountPerTimePeriod;

    // zZoneTimePeriodPerMaximumAmount - 32 bit
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckZZoneTimePeriodPerMaximumAmount = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneTimePeriodPerMaximumAmount.in <== zZoneTimePeriodPerMaximumAmount;

    // zZoneDataEscrowEncryptedMessageAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheckZZoneDataEscrowEncryptedMessageAx = RangeCheckGroupOfSignals(1,252,(2**252 - 1),0); 
    // customRangeCheckZZoneDataEscrowEncryptedMessageAx.in <== zZoneDataEscrowEncryptedMessageAx;

    // zZoneDataEscrowEncryptedMessageAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheckZZoneDataEscrowEncryptedMessageAy = RangeCheckGroupOfSignals(1,252,(2**252 - 1),0); 
    // customRangeCheckZZoneDataEscrowEncryptedMessageAy.in <== zZoneDataEscrowEncryptedMessageAy;

    // kytEdDsaPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheckKytEdDsaPubKey = RangeCheckGroupOfSignals(2,252,(2**252 - 1),0);
    // customRangeCheckKytEdDsaPubKey.in <== kytEdDsaPubKey;

    // kytEdDsaPubKeyExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckKytEdDsaPubKeyExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckKytEdDsaPubKeyExpiryTime.in <== kytEdDsaPubKeyExpiryTime;

    // trustProvidersMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    
    // kytPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    
    // kytPathIndices - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Needs to check 1 bit?
    // component customRangeCheckKytPathIndices = RangeCheckGroupOfSignals(16,252,(2**252 - 1),0);
    // customRangeCheckKytPathIndices.in <== kytPathIndices;

    // kytMerkleTreeLeafIDsAndRulesOffset - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheckKytMerkleTreeLeafIDsAndRulesOffset = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckKytMerkleTreeLeafIDsAndRulesOffset.in <== kytMerkleTreeLeafIDsAndRulesOffset;

    // kytDepositSignedMessagePackageType - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheckKytDepositSignedMessagePackageType = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheckKytDepositSignedMessagePackageType.in <== kytDepositSignedMessagePackageType;

    // kytDepositSignedMessageTimestamp - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckKytDepositSignedMessageTimestamp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckKytDepositSignedMessageTimestamp.in <== kytDepositSignedMessageTimestamp;

    // kytDepositSignedMessageSender - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytDepositSignedMessageSender = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytDepositSignedMessageSender.in <== kytDepositSignedMessageSender;

    // kytDepositSignedMessageReceiver - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytDepositSignedMessageReceiver = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytDepositSignedMessageReceiver.in <== kytDepositSignedMessageReceiver;

    // kytDepositSignedMessageToken - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytDepositSignedMessageToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytDepositSignedMessageToken.in <== kytDepositSignedMessageToken;

    // kytDepositSignedMessageSessionId - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - if it is strictly 256 then it needs to be checked in SC?
    // component customRangeCheckKytDepositSignedMessageSessionId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckKytDepositSignedMessageSessionId.in <== kytDepositSignedMessageSessionId;

    // kytDepositSignedMessageRuleId - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheckKytDepositSignedMessageRuleId = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheckKytDepositSignedMessageRuleId.in <== kytDepositSignedMessageRuleId;

    // kytDepositSignedMessageAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckKytDepositSignedMessageAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckKytDepositSignedMessageAmount.in <== kytDepositSignedMessageAmount;

    // kytDepositSignedMessageSigner - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytDepositSignedMessageSigner = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytDepositSignedMessageSigner.in <== kytDepositSignedMessageSigner;

    // kytDepositSignedMessageHash
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kytDepositSignature
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheckKytDepositSignature = RangeCheckGroupOfSignals(3,252,(2**252 - 1),0);
    // customRangeCheckKytDepositSignature.in <== kytDepositSignature;

    // kytWithdrawSignedMessagePackageType - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheckKytWithdrawSignedMessagePackageType = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheckKytWithdrawSignedMessagePackageType.in <== kytWithdrawSignedMessagePackageType;

    // kytWithdrawSignedMessageTimestamp - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckKytWithdrawSignedMessageTimestamp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckKytWithdrawSignedMessageTimestamp.in <== kytWithdrawSignedMessageTimestamp;

    // kytWithdrawSignedMessageSender - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytWithdrawSignedMessageSender = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytWithdrawSignedMessageSender.in <== kytWithdrawSignedMessageSender;

    // kytWithdrawSignedMessageReceiver - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytWithdrawSignedMessageReceiver = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytWithdrawSignedMessageReceiver.in <== kytWithdrawSignedMessageReceiver;

    // kytWithdrawSignedMessageToken - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytWithdrawSignedMessageToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytWithdrawSignedMessageToken.in <== kytWithdrawSignedMessageToken;

    // kytWithdrawSignedMessageSessionId - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - session id strictly 256 bits?
    component customRangeCheckKytWithdrawSignedMessageSessionId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckKytWithdrawSignedMessageSessionId.in <== kytWithdrawSignedMessageSessionId;

    // kytWithdrawSignedMessageRuleId - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheckKytWithdrawSignedMessageRuleId = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheckKytWithdrawSignedMessageRuleId.in <== kytWithdrawSignedMessageRuleId;

    // kytWithdrawSignedMessageAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckKytWithdrawSignedMessageAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckKytWithdrawSignedMessageAmount.in <== kytWithdrawSignedMessageAmount;

    // kytWithdrawSignedMessageSigner - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheckKytWithdrawSignedMessageSigner = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckKytWithdrawSignedMessageSigner.in <== kytWithdrawSignedMessageSigner;

    // kytWithdrawSignedMessageHash
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheckKytWithdrawSignedMessageHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheckKytWithdrawSignedMessageHash.in <== kytWithdrawSignedMessageHash;

    // kytWithdrawSignature
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheckKytWithdrawSignature = RangeCheckGroupOfSignals(3,252,(2**252 - 1),0);
    // customRangeCheckKytWithdrawSignature.in <== kytWithdrawSignature;

    // dataEscrowPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowPubKeyExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheckDataEscrowPubKeyExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckDataEscrowPubKeyExpiryTime.in <== dataEscrowPubKeyExpiryTime;

    // dataEscrowEphimeralRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    
    // dataEscrowEphimeralPubKeyAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowEphimeralPubKeyAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // ToDo - Restrict path indices to 1 bit?
    // component customRangeCheckDataEscrowPathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheckDataEscrowPathIndices.in <== dataEscrowPathIndices;

    // dataEscrowEncryptedMessageAx - 256 bits
    // Public signal 
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // dataEscrowEncryptedMessageAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEphimeralRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEphimeralPubKeyAx - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEphimeralPubKeyAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEncryptedMessageAx - 256 bits
    // Public signal 
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEncryptedMessageAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC
    
    // utxoOutCreateTime - 32 bits
    // Public signal  
    // Supported range - [0 to (2**32 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckUtxoOutCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckUtxoOutCreateTime.in <== utxoOutCreateTime;

    // utxoOutAmount - 64 bits
    // circom supported bits - 2**64
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheckUtxoOutAmount = RangeCheckGroupOfSignals(2, 64,(2**64 - 1),0);
    customRangeCheckUtxoOutAmount.in <== utxoOutAmount;

    // utxoOutOriginNetworkId - 6 bits
    // circom supported bits - 2**6
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckUtxoOutOriginNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0);
    customRangeCheckUtxoOutOriginNetworkId.in <== utxoOutOriginNetworkId;

    // utxoOutTargetNetworkId - 6 bit
    // circom supported bits - 2**6
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckUtxoOutTargetNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0);
    customRangeCheckUtxoOutTargetNetworkId.in <== utxoOutTargetNetworkId;

    // utxoOutTargetZoneId - 16 bits
    // circom supported bits - 2**16
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheckUtxoOutTargetZoneId = RangeCheckGroupOfSignals(2, 16,(2**16 - 1),0);
    customRangeCheckUtxoOutTargetZoneId.in <== utxoOutTargetZoneId;

    // utxoOutTargetZoneIdOffset - 4 bits
    // circom supported bits - 2**4
    // Supported range - [0 to (2**4 - 1)]
    component customRangeCheckUtxoOutTargetZoneIdOffset = RangeCheckGroupOfSignals(2, 4,(2**4 - 1),0);
    customRangeCheckUtxoOutTargetZoneIdOffset.in <== utxoOutTargetZoneIdOffset;

    // utxoOutSpendPubKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // utxoOutRootSpendPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // utxoOutCommitment
    // Public signal    
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoOutZkpAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheckZAccountUtxoOutZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoOutZkpAmount.in <== zAccountUtxoOutZkpAmount;

    // zAccountUtxoOutSpendKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoOutCommitment
    // Public signal  
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // chargedAmountZkp - 256 bits
    // Public signal  
    // Should be checked as part of the SC
    component customRangeCheckChargedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckChargedAmountZkp.in <== chargedAmountZkp;

    // zNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheckZNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZNetworkId.in <== zNetworkId;

    // zNetworkChainId - 256 bits
    // Public signal  
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zNetworkIDsBitMap - 64 bits
    // Supported range - [0 to (2**64 - 1)]
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

    // staticTreeMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // forestMerkleRoot
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // taxiMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // busMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // ferryMerkleRoot
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
