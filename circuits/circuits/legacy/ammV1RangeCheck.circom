//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./templates/rangeCheck.circom";

template AmmV1RangeCheck  ( UtxoLeftMerkleTreeDepth,
                            UtxoMiddleMerkleTreeDepth,
                            ZNetworkMerkleTreeDepth,
                            ZAssetMerkleTreeDepth,
                            ZAccountBlackListMerkleTreeDepth,
                            ZZoneMerkleTreeDepth) {

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

    // createTime - 32 bits
    // Public signal
    // Supported range - [0 - (2**32 - 1)]
    // Must be checked as part of SC
    component customRangeCheckCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckCreateTime.in <== createTime;

    // depositAmountPrp - 64 bits
    // Public signal
    // Supported range - [0 - (2**64 - 1)]
    // Must be checked as part of SC
    component customRangeCheckDepositAmountPrp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckDepositAmountPrp.in <== depositAmountPrp;

    // withdrawAmountPrp - 64 bits
    // Public signal
    // Supported range - [0 - (2**64 - 1)]
    // Must be checked as part of SC
    component customRangeCheckWithdrawAmountPrp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckWithdrawAmountPrp.in <== withdrawAmountPrp;

    // utxoCommitment
    // Public signal
    // Must be within the SNARK_FIELD
    // Must be checked as part of SC

    // utxoSpendPubKey - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // utxoSpendKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

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
    component customRangeCheckZAssetTokenId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAssetTokenId.in <== zAssetTokenId;

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
    // Supported range - [0 - (2**252 - 1)]
    // Public signal - Checked as part of SC
    component customRangeCheckZAssetScale = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAssetScale.in <== zAssetScale;

    // zAssetMerkleRoot - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAssetPathIndices - 256 bits
    // ToDo - Path Indices should be fixed to 1 bit?
    component customRangeCheckZAssetPathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    customRangeCheckZAssetPathIndices.in <== zAssetPathIndices;

    // zAssetPathElements - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoInId - 24 bits
    // Supported range - [0 - (2**24 - 1)]
    component customRangeCheckZAccountUtxoInId = RangeCheckSingleSignal(24,(2**24 - 1),0);
    customRangeCheckZAccountUtxoInId.in <== zAccountUtxoInId;

    // zAccountUtxoInZkpAmount - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInZkpAmount.in <== zAccountUtxoInZkpAmount;

    // zAccountUtxoInPrpAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZAccountUtxoInPrpAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAccountUtxoInPrpAmount.in <== zAccountUtxoInPrpAmount;

    // zAccountUtxoInZoneId - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckZAccountUtxoInZoneId = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountUtxoInZoneId.in <== zAccountUtxoInZoneId;

    // zAccountUtxoInNetworkId - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZAccountUtxoInNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZAccountUtxoInNetworkId.in <== zAccountUtxoInNetworkId;

    // zAccountUtxoInExpiryTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZAccountUtxoInExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZAccountUtxoInExpiryTime.in <== zAccountUtxoInExpiryTime;

    // zAccountUtxoInNonce - 16 bits
    // Supported range - [0 - (2**16 - 1)]
    component customRangeCheckZAccountUtxoInNonce = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheckZAccountUtxoInNonce.in <== zAccountUtxoInNonce;

    // zAccountUtxoInTotalAmountPerTimePeriod - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoInTotalAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoInTotalAmountPerTimePeriod.in <== zAccountUtxoInTotalAmountPerTimePeriod;

    // zAccountUtxoInCreateTime - 32 bits
    // Supported range - [0 - (2**32 - 1)]
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

    // zAccountUtxoInSpendPrivKey - 256 bits
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInNullifierPrivKey - 256 bits
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInMasterEOA - 160 bits
    // Supported range - [0 - (2**160 - 1)]
    component customRangeCheckZAccountUtxoInMasterEOA = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheckZAccountUtxoInMasterEOA.in <== zAccountUtxoInMasterEOA;

    // zAccountUtxoInSpendKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoInCommitment
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoInNullifier
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoInMerkleTreeSelector - 2 bits
    // Supported range - [0 - (2**2 - 1)]
    component customRangeCheckZAccountUtxoInMerkleTreeSelector = RangeCheckGroupOfSignals(2, 2, (2**2 - 1), 0);
    customRangeCheckZAccountUtxoInMerkleTreeSelector.in <== zAccountUtxoInMerkleTreeSelector;

    // zAccountUtxoInPathIndices - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Needs to check 1 bit?
    component customRangeCheckZAccountUtxoInPathIndices = RangeCheckGroupOfSignals(32, 252, (2**252 - 1), 0);
    customRangeCheckZAccountUtxoInPathIndices.in <== zAccountUtxoInPathIndices;

    // zAccountUtxoInPathElements - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoOutZkpAmount - 252 bits
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountUtxoOutZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoOutZkpAmount.in <== zAccountUtxoOutZkpAmount;

    // zAccountUtxoOutPrpAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZAccountUtxoOutPrpAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZAccountUtxoOutPrpAmount.in <== zAccountUtxoOutPrpAmount;

    // zAccountUtxoOutSpendKeyRandom - 256 bits
     // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    component customRangeCheckZAccountUtxoOutSpendKeyRandom = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountUtxoOutSpendKeyRandom.in <== zAccountUtxoOutSpendKeyRandom;

    // zAccountUtxoOutCommitment - 256 bits
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListLeaf - 256 bits
    // circom supported bits - 2**252
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZAccountBlackListLeaf = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZAccountBlackListLeaf.in <== zAccountBlackListLeaf;

    // zAccountBlackListMerkleRoot - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListPathElements - 256 bits
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

    // zZoneWithdrawMaxAmount - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZZoneWithrawMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZZoneWithrawMaxAmount.in <== zZoneWithdrawMaxAmount;

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

    // zZonePathIndices - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Needs to check 1 bit?
    // Merkle Tree related details are range checked from dApp and SC.
    component customRangeCheckZZonePathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    customRangeCheckZZonePathIndices.in <== zZonePathIndices;

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
    // Supported range - [0 - (2**252 - 1)]
    component customRangeCheckZZoneMaximumAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZZoneMaximumAmountPerTimePeriod.in <== zZoneMaximumAmountPerTimePeriod;

    // zZoneTimePeriodPerMaximumAmount - 32 bit
    // Supported range - [0 - (2**32 - 1)]
    component customRangeCheckZZoneTimePeriodPerMaximumAmount = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheckZZoneTimePeriodPerMaximumAmount.in <== zZoneTimePeriodPerMaximumAmount;

    // zNetworkId - 6 bits
    // Supported range - [0 - (2**6 - 1)]
    component customRangeCheckZNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheckZNetworkId.in <== zNetworkId;

    // zNetworkChainId - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    component customRangeCheckZNetworkChainId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheckZNetworkChainId.in <== zNetworkChainId;

    // zNetworkIDsBitMap - 64 bits
    // Supported range - [0 - (2**64 - 1)]
    component customRangeCheckZNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheckZNetworkIDsBitMap.in <== zNetworkIDsBitMap;

    // zNetworkTreeMerkleRoot - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkTreePathElements - 256 bits
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkTreePathIndices 256 bits
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

    // trustProvidersMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // staticTreeMerkleRoot
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

    // saltHash - 256 bits
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // magicalConstraint - 256 bits
    // Public signal
    // Should be checked as part of the SC
}
