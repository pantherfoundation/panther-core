//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

// project deps
include "./templates/balanceChecker.circom";
include "./templates/isNotZero.circom";
include "./templates/trustProvidersMerkleTreeLeafIdAndRuleInclusionProver.circom";
include "./templates/trustProvidersNoteInclusionProver.circom";
include "./templates/pubKeyDeriver.circom";
include "./templates/zAccountNoteInclusionProver.circom";
include "./templates/zAccountBlackListLeafInclusionProver.circom";
include "./templates/zAccountNoteHasher.circom";
include "./templates/zAccountNullifierHasher.circom";
include "./templates/zAssetChecker.circom";
include "./templates/zAssetNoteInclusionProver.circom";
include "./templates/zNetworkNoteInclusionProver.circom";
include "./templates/zZoneNoteHasher.circom";
include "./templates/zZoneNoteInclusionProver.circom";
include "./templates/zZoneZAccountBlackListExclusionProver.circom";
include "./templates/utxoNoteHasher.circom";
include "./templates/utils.circom";
include "./ammV1RangeCheck.circom";

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template AmmV1 ( UtxoLeftMerkleTreeDepth,
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
    signal input zZoneWithrawMaxAmount;
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

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [0] - Extra inputs hash anchoring
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    extraInputsHash === 1 * extraInputsHash;

    // [1] - Verify zAsset's membership and decode its weight
    component zAssetNoteInclusionProver = ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth);
    zAssetNoteInclusionProver.zAsset <== zAssetId;
    zAssetNoteInclusionProver.token <== zAssetToken;
    zAssetNoteInclusionProver.tokenId <== zAssetTokenId;
    zAssetNoteInclusionProver.network <== zAssetNetwork;
    zAssetNoteInclusionProver.offset <== zAssetOffset;
    zAssetNoteInclusionProver.weight <== zAssetWeight;
    zAssetNoteInclusionProver.scale <== zAssetScale;
    zAssetNoteInclusionProver.merkleRoot <== zAssetMerkleRoot;

    for (var i = 0; i < ZAssetMerkleTreeDepth; i++) {
        zAssetNoteInclusionProver.pathIndices[i] <== zAssetPathIndices[i];
        zAssetNoteInclusionProver.pathElements[i] <== zAssetPathElements[i];
    }

    // [2] - Check zAsset
    component zAssetChecker = ZAssetChecker();
    zAssetChecker.token <== 0;
    zAssetChecker.tokenId <== 0;
    zAssetChecker.zAssetId <== zAssetId;
    zAssetChecker.zAssetToken <== zAssetToken;
    zAssetChecker.zAssetTokenId <== zAssetTokenId;
    zAssetChecker.zAssetOffset <== zAssetOffset;
    zAssetChecker.depositAmount <== 0;
    zAssetChecker.withdrawAmount <== 0;
    zAssetChecker.utxoZAssetId <== zAssetId;

    // [3] - Zkp balance
    component totalBalanceChecker = BalanceChecker();
    totalBalanceChecker.isZkpToken <== zAssetChecker.isZkpToken;
    totalBalanceChecker.depositAmount <== 0;
    totalBalanceChecker.depositChange <== 0;
    totalBalanceChecker.withdrawAmount <== 0;
    totalBalanceChecker.withdrawChange <== 0;
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.addedAmountZkp <== addedAmountZkp;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== 0;
    totalBalanceChecker.totalUtxoOutAmount <== 0;
    totalBalanceChecker.zAssetWeight <== zAssetWeight;
    totalBalanceChecker.zAssetScale <== zAssetScale;
    totalBalanceChecker.zAssetScaleZkp <== zAssetScale;
    totalBalanceChecker.kytDepositChargedAmountZkp <== 0;
    totalBalanceChecker.kytWithdrawChargedAmountZkp <== 0;
    totalBalanceChecker.kytInternalChargedAmountZkp <== 0;

    // verify zAsset is ZKP
    zAssetChecker.isZkpToken === 1;

    // [4] - Verify input 'zAccount UTXO input'
    // derive spend pub key
    component zAccountUtxoInSpendPubKeyDeriver = PubKeyDeriver();
    zAccountUtxoInSpendPubKeyDeriver.rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoInSpendPubKeyDeriver.rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoInSpendPubKeyDeriver.random <== zAccountUtxoInSpendKeyRandom; // random generated by sender

    component zAccountUtxoInSpendPubKeyCheck = BabyPbk();
    zAccountUtxoInSpendPubKeyCheck.in <== zAccountUtxoInSpendPrivKey;

    // verify spend key
    zAccountUtxoInSpendPubKeyDeriver.derivedPubKey[0] === zAccountUtxoInSpendPubKeyCheck.Ax;
    zAccountUtxoInSpendPubKeyDeriver.derivedPubKey[1] === zAccountUtxoInSpendPubKeyCheck.Ay;

    component zAccountUtxoInNoteHasher = ZAccountNoteHasher();
    zAccountUtxoInNoteHasher.spendPubKey[0] <== zAccountUtxoInSpendPubKeyDeriver.derivedPubKey[0];
    zAccountUtxoInNoteHasher.spendPubKey[1] <== zAccountUtxoInSpendPubKeyDeriver.derivedPubKey[1];
    zAccountUtxoInNoteHasher.rootSpendPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoInNoteHasher.rootSpendPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoInNoteHasher.readPubKey[0] <== zAccountUtxoInReadPubKey[0];
    zAccountUtxoInNoteHasher.readPubKey[1] <== zAccountUtxoInReadPubKey[1];
    zAccountUtxoInNoteHasher.nullifierPubKey[0] <== zAccountUtxoInNullifierPubKey[0];
    zAccountUtxoInNoteHasher.nullifierPubKey[1] <== zAccountUtxoInNullifierPubKey[1];
    zAccountUtxoInNoteHasher.masterEOA <== zAccountUtxoInMasterEOA;
    zAccountUtxoInNoteHasher.id <== zAccountUtxoInId;
    zAccountUtxoInNoteHasher.amountZkp <== zAccountUtxoInZkpAmount;
    zAccountUtxoInNoteHasher.amountPrp <== zAccountUtxoInPrpAmount;
    zAccountUtxoInNoteHasher.zoneId <== zAccountUtxoInZoneId;
    zAccountUtxoInNoteHasher.expiryTime <== zAccountUtxoInExpiryTime;
    zAccountUtxoInNoteHasher.nonce <== zAccountUtxoInNonce;
    zAccountUtxoInNoteHasher.totalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zAccountUtxoInNoteHasher.createTime <== zAccountUtxoInCreateTime;
    zAccountUtxoInNoteHasher.networkId <== zAccountUtxoInNetworkId;

    // verify zNetworkId is equal to zAccountUtxoInNetworkId (anchoring)
    zAccountUtxoInNetworkId === zNetworkId;

    // verify prp amount to be used in AMM - balance check
    assert(zAccountUtxoInPrpAmount + depositAmountPrp >= withdrawAmountPrp);
    component withdrawPrpIsLessThanZAccountPrpPlusDepositPrp;
    withdrawPrpIsLessThanZAccountPrpPlusDepositPrp = LessEqThan(32);
    withdrawPrpIsLessThanZAccountPrpPlusDepositPrp.in[0] <== withdrawAmountPrp;
    withdrawPrpIsLessThanZAccountPrpPlusDepositPrp.in[1] <== (zAccountUtxoInPrpAmount + depositAmountPrp);
    withdrawPrpIsLessThanZAccountPrpPlusDepositPrp.out === 1;

    zAccountUtxoOutPrpAmount === zAccountUtxoInPrpAmount + depositAmountPrp - withdrawAmountPrp;

    // [5] - Verify zAccountUtxoInUtxo commitment
    component zAccountUtxoInHasherProver = ForceEqualIfEnabled();
    zAccountUtxoInHasherProver.in[0] <== zAccountUtxoInCommitment;
    zAccountUtxoInHasherProver.in[1] <== zAccountUtxoInNoteHasher.out;
    zAccountUtxoInHasherProver.enabled <== zAccountUtxoInCommitment;

    // [6] - Verify zAccountUtxoIn membership
    component zAccountUtxoInMerkleVerifier = MerkleTreeInclusionProofDoubleLeavesSelectable(UtxoLeftMerkleTreeDepth,UtxoMiddleExtraLevels,UtxoRightExtraLevels);
    zAccountUtxoInMerkleVerifier.leaf <== zAccountUtxoInNoteHasher.out;
    for (var i = 0; i < UtxoMerkleTreeDepth; i++) {
        zAccountUtxoInMerkleVerifier.pathIndices[i] <== zAccountUtxoInPathIndices[i];
        zAccountUtxoInMerkleVerifier.pathElements[i] <== zAccountUtxoInPathElements[i];
    }
    // tree selector
    zAccountUtxoInMerkleVerifier.treeSelector[0] <== zAccountUtxoInMerkleTreeSelector[0];
    zAccountUtxoInMerkleVerifier.treeSelector[1] <== zAccountUtxoInMerkleTreeSelector[1];

    // choose the root to return, based upon `treeSelector`
    component zAccountRootSelectorSwitch = Selector3();
    zAccountRootSelectorSwitch.sel[0] <== zAccountUtxoInMerkleTreeSelector[0];
    zAccountRootSelectorSwitch.sel[1] <== zAccountUtxoInMerkleTreeSelector[1];
    zAccountRootSelectorSwitch.L <== taxiMerkleRoot;
    zAccountRootSelectorSwitch.M <== busMerkleRoot;
    zAccountRootSelectorSwitch.R <== ferryMerkleRoot;

    // verify computed root against provided one
    component isEqualZAccountMerkleRoot = ForceEqualIfEnabled();
    isEqualZAccountMerkleRoot.in[0] <== zAccountRootSelectorSwitch.out;
    isEqualZAccountMerkleRoot.in[1] <== zAccountUtxoInMerkleVerifier.root;
    isEqualZAccountMerkleRoot.enabled <== zAccountRootSelectorSwitch.out;

    // [7] - Verify zAccountUtxoIn nullifier
    // verify nullifier key
    component zAccountNullifierPubKeyChecker = BabyPbk();
    zAccountNullifierPubKeyChecker.in <== zAccountUtxoInNullifierPrivKey;
    zAccountNullifierPubKeyChecker.Ax === zAccountUtxoInNullifierPubKey[0];
    zAccountNullifierPubKeyChecker.Ay === zAccountUtxoInNullifierPubKey[1];

    component zAccountUtxoInNullifierHasher = ZAccountNullifierHasher();
    zAccountUtxoInNullifierHasher.privKey <== zAccountUtxoInNullifierPrivKey;
    zAccountUtxoInNullifierHasher.commitment <== zAccountUtxoInNoteHasher.out;

    component zAccountUtxoInNullifierHasherProver = ForceEqualIfEnabled();
    zAccountUtxoInNullifierHasherProver.in[0] <== zAccountUtxoInNullifier;
    zAccountUtxoInNullifierHasherProver.in[1] <== zAccountUtxoInNullifierHasher.out;
    zAccountUtxoInNullifierHasherProver.enabled <== zAccountUtxoInNullifier;

    // [8] - Verify zAccoutId exclusion proof
    component zAccountBlackListInlcusionProver = ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.zAccountId <== zAccountUtxoInId;
    zAccountBlackListInlcusionProver.leaf <== zAccountBlackListLeaf;
    zAccountBlackListInlcusionProver.merkleRoot <== zAccountBlackListMerkleRoot;
    for (var j = 0; j < ZZoneMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== zAccountBlackListPathElements[j];
    }

    // [9] - Verify zAccount UTXO out
    // derive spend pub key
    component zAccountUtxoOutSpendPubKeyDeriver = PubKeyDeriver();
    zAccountUtxoOutSpendPubKeyDeriver.rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoOutSpendPubKeyDeriver.rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoOutSpendPubKeyDeriver.random <== zAccountUtxoOutSpendKeyRandom; // random generated by sender

    component zAccountUtxoOutNoteHasher = ZAccountNoteHasher();
    zAccountUtxoOutNoteHasher.spendPubKey[0] <== zAccountUtxoOutSpendPubKeyDeriver.derivedPubKey[0];
    zAccountUtxoOutNoteHasher.spendPubKey[1] <== zAccountUtxoOutSpendPubKeyDeriver.derivedPubKey[1];
    zAccountUtxoOutNoteHasher.rootSpendPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoOutNoteHasher.rootSpendPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoOutNoteHasher.readPubKey[0] <== zAccountUtxoInReadPubKey[0];
    zAccountUtxoOutNoteHasher.readPubKey[1] <== zAccountUtxoInReadPubKey[1];
    zAccountUtxoOutNoteHasher.nullifierPubKey[0] <== zAccountUtxoInNullifierPubKey[0];
    zAccountUtxoOutNoteHasher.nullifierPubKey[1] <== zAccountUtxoInNullifierPubKey[1];
    zAccountUtxoOutNoteHasher.masterEOA <== zAccountUtxoInMasterEOA;
    zAccountUtxoOutNoteHasher.id <== zAccountUtxoInId;
    zAccountUtxoOutNoteHasher.amountZkp <== zAccountUtxoOutZkpAmount;
    zAccountUtxoOutNoteHasher.amountPrp <== zAccountUtxoOutPrpAmount;
    zAccountUtxoOutNoteHasher.zoneId <== zAccountUtxoInZoneId;
    zAccountUtxoOutNoteHasher.expiryTime <== zAccountUtxoInExpiryTime;
    zAccountUtxoOutNoteHasher.nonce <== zAccountUtxoInNonce + 1;
    zAccountUtxoOutNoteHasher.totalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zAccountUtxoOutNoteHasher.createTime <== createTime;
    zAccountUtxoOutNoteHasher.networkId <== zAccountUtxoInNetworkId;

    // verify expiryTime
    assert(zAccountUtxoInExpiryTime >= createTime);
    component createTimeIsLessThanZaccountUtxoInExpiryTime;
    createTimeIsLessThanZaccountUtxoInExpiryTime = LessEqThan(32);
    createTimeIsLessThanZaccountUtxoInExpiryTime.in[0] <== createTime;
    createTimeIsLessThanZaccountUtxoInExpiryTime.in[1] <== zAccountUtxoInExpiryTime;
    createTimeIsLessThanZaccountUtxoInExpiryTime.out === 1;

    // [10] - Verify zAccountUtxoOut commitment
    component zAccountUtxoOutHasherProver = ForceEqualIfEnabled();
    zAccountUtxoOutHasherProver.in[0] <== zAccountUtxoOutCommitment;
    zAccountUtxoOutHasherProver.in[1] <== zAccountUtxoOutNoteHasher.out;
    zAccountUtxoOutHasherProver.enabled <== zAccountUtxoOutCommitment;

    // [11] - Utxo hidden part generation & commitment
    var isHiddenHash = 1;
    component utxoNoteHasher = UtxoNoteHasher(isHiddenHash);
    utxoNoteHasher.zAsset <== zAssetId;
    utxoNoteHasher.amount <== 0; // not in use since hidden hash does not have it
    utxoNoteHasher.spendPk[0] <== utxoSpendPubKey[0];
    utxoNoteHasher.spendPk[1] <== utxoSpendPubKey[1];
    utxoNoteHasher.originNetworkId <== zNetworkId;
    utxoNoteHasher.targetNetworkId <== zNetworkId;
    utxoNoteHasher.createTime <== createTime;
    utxoNoteHasher.originZoneId <== zAccountUtxoInZoneId;
    utxoNoteHasher.targetZoneId <== zAccountUtxoInZoneId;
    utxoNoteHasher.zAccountId <== zAccountUtxoInId;
    utxoNoteHasher.dataEscrowPubKey[0] <== zZoneDataEscrowPubKey[0];
    utxoNoteHasher.dataEscrowPubKey[1] <== zZoneDataEscrowPubKey[1];

    component utxoCommitmentIsEqual = ForceEqualIfEnabled();
    utxoCommitmentIsEqual.enabled <== utxoCommitment;
    utxoCommitmentIsEqual.in[0] <== utxoCommitment;
    utxoCommitmentIsEqual.in[1] <== utxoNoteHasher.out;

    // [12] - derive utxo spend pub key & verify
    component utxoInSpendPubKeyDeriver = PubKeyDeriver();
    utxoInSpendPubKeyDeriver.rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    utxoInSpendPubKeyDeriver.rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    utxoInSpendPubKeyDeriver.random <== utxoSpendKeyRandom; // random generated by sender

    // verify
    utxoSpendPubKey[0] === utxoInSpendPubKeyDeriver.derivedPubKey[0];
    utxoSpendPubKey[1] === utxoInSpendPubKeyDeriver.derivedPubKey[1];

    // [13] - Verify zZone membership
    component zZoneNoteHasher = ZZoneNoteHasher();
    zZoneNoteHasher.zoneId <== zAccountUtxoInZoneId;
    zZoneNoteHasher.edDsaPubKey[0] <== zZoneEdDsaPubKey[0];
    zZoneNoteHasher.edDsaPubKey[1] <== zZoneEdDsaPubKey[1];
    zZoneNoteHasher.originZoneIDs <== zZoneOriginZoneIDs;
    zZoneNoteHasher.targetZoneIDs <== zZoneTargetZoneIDs;
    zZoneNoteHasher.networkIDsBitMap <== zZoneNetworkIDsBitMap;
    zZoneNoteHasher.trustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zZoneNoteHasher.kycExpiryTime <== zZoneKycExpiryTime;
    zZoneNoteHasher.kytExpiryTime <== zZoneKytExpiryTime;
    zZoneNoteHasher.depositMaxAmount <== zZoneDepositMaxAmount;
    zZoneNoteHasher.withdrawMaxAmount <== zZoneWithrawMaxAmount;
    zZoneNoteHasher.internalMaxAmount <== zZoneInternalMaxAmount;
    zZoneNoteHasher.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;
    zZoneNoteHasher.maximumAmountPerTimePeriod <== zZoneMaximumAmountPerTimePeriod;
    zZoneNoteHasher.timePeriodPerMaximumAmount <== zZoneTimePeriodPerMaximumAmount;
    zZoneNoteHasher.dataEscrowPubKey[0] <== zZoneDataEscrowPubKey[0];
    zZoneNoteHasher.dataEscrowPubKey[1] <== zZoneDataEscrowPubKey[1];
    zZoneNoteHasher.sealing <== zZoneSealing;

    component zZoneInclusionProver = ZZoneNoteInclusionProver(ZZoneMerkleTreeDepth);
    zZoneInclusionProver.zZoneCommitment <== zZoneNoteHasher.out;
    zZoneInclusionProver.root <== zZoneMerkleRoot;
    for (var j=0; j < ZZoneMerkleTreeDepth; j++) {
        zZoneInclusionProver.pathIndices[j] <== zZonePathIndices[j];
        zZoneInclusionProver.pathElements[j] <== zZonePathElements[j];
    }

    // [14] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountUtxoInId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [15] - Verify zNetwork's membership
    component zNetworkNoteInclusionProver = ZNetworkNoteInclusionProver(ZNetworkMerkleTreeDepth);
    zNetworkNoteInclusionProver.active <== 1; // ALLWAYS ACTIVE
    zNetworkNoteInclusionProver.networkId <== zNetworkId;
    zNetworkNoteInclusionProver.chainId <== zNetworkChainId;
    zNetworkNoteInclusionProver.networkIDsBitMap <== zNetworkIDsBitMap;
    zNetworkNoteInclusionProver.forTxReward <== forTxReward;
    zNetworkNoteInclusionProver.forUtxoReward <== forUtxoReward;
    zNetworkNoteInclusionProver.forDepositReward <== forDepositReward;
    zNetworkNoteInclusionProver.daoDataEscrowPubKey[0] <== daoDataEscrowPubKey[0];
    zNetworkNoteInclusionProver.daoDataEscrowPubKey[1] <== daoDataEscrowPubKey[1];
    zNetworkNoteInclusionProver.merkleRoot <== zNetworkTreeMerkleRoot;

    for (var i = 0; i < ZNetworkMerkleTreeDepth; i++) {
        zNetworkNoteInclusionProver.pathIndices[i] <== zNetworkTreePathIndices[i];
        zNetworkNoteInclusionProver.pathElements[i] <== zNetworkTreePathElements[i];
    }

    // [16] - Verify static-merkle-root
    component staticTreeMerkleRootVerifier = Poseidon(5);
    staticTreeMerkleRootVerifier.inputs[0] <== zAssetMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[1] <== zAccountBlackListMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[2] <== zNetworkTreeMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[3] <== zZoneMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[4] <== trustProvidersMerkleRoot;

    // verify computed root against provided one
    component isEqualStaticTreeMerkleRoot = ForceEqualIfEnabled();
    isEqualStaticTreeMerkleRoot.in[0] <== staticTreeMerkleRootVerifier.out;
    isEqualStaticTreeMerkleRoot.in[1] <== staticTreeMerkleRoot;
    isEqualStaticTreeMerkleRoot.enabled <== staticTreeMerkleRoot;

    // [17] - Verify forest-merkle-roots
    component forestTreeMerkleRootVerifier = Poseidon(3);
    forestTreeMerkleRootVerifier.inputs[0] <== taxiMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[1] <== busMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[2] <== ferryMerkleRoot;

    // verify computed root against provided one
    component isEqualForestTreeMerkleRoot = ForceEqualIfEnabled();
    isEqualForestTreeMerkleRoot.in[0] <== forestTreeMerkleRootVerifier.out;
    isEqualForestTreeMerkleRoot.in[1] <== forestMerkleRoot;
    isEqualForestTreeMerkleRoot.enabled <== forestMerkleRoot;

    // [18] - Verify salt
    component saltVerify = Poseidon(1);
    saltVerify.inputs[0] <== salt;

    component isEqualSalt = ForceEqualIfEnabled();
    isEqualSalt.in[0] <== saltVerify.out;
    isEqualSalt.in[1] <== saltHash;
    isEqualSalt.enabled <== saltHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [19] - Magical Contraint check ////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;

    // //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // // [20] - Range check ////////////////////////////////////////////////////////////////////////////////////
    // //////////////////////////////////////////////////////////////////////////////////////////////////////////

    component ammV1RC = AmmV1RangeCheck ( UtxoLeftMerkleTreeDepth,
                                          UtxoMiddleMerkleTreeDepth,
                                          ZNetworkMerkleTreeDepth,
                                          ZAssetMerkleTreeDepth,
                                          ZAccountBlackListMerkleTreeDepth,
                                          ZZoneMerkleTreeDepth);

    ammV1RC.extraInputsHash <== extraInputsHash;

    ammV1RC.addedAmountZkp <== addedAmountZkp;
    ammV1RC.chargedAmountZkp <== chargedAmountZkp;
    ammV1RC.createTime <== createTime;
    ammV1RC.depositAmountPrp <== depositAmountPrp;
    ammV1RC.withdrawAmountPrp <== withdrawAmountPrp;

    ammV1RC.utxoCommitment <== utxoCommitment;
    ammV1RC.utxoSpendPubKey <== utxoSpendPubKey;
    ammV1RC.utxoSpendKeyRandom <== utxoSpendKeyRandom;

    ammV1RC.zAssetId <== zAssetId;
    ammV1RC.zAssetToken <== zAssetToken;
    ammV1RC.zAssetTokenId <== zAssetTokenId;
    ammV1RC.zAssetNetwork <== zAssetNetwork;
    ammV1RC.zAssetOffset <== zAssetOffset;
    ammV1RC.zAssetWeight <== zAssetWeight;
    ammV1RC.zAssetScale <== zAssetScale;
    ammV1RC.zAssetMerkleRoot <== zAssetMerkleRoot;
    ammV1RC.zAssetPathIndices <== zAssetPathIndices;
    ammV1RC.zAssetPathElements <== zAssetPathElements;

    ammV1RC.zAccountUtxoInId <== zAccountUtxoInId;
    ammV1RC.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    ammV1RC.zAccountUtxoInPrpAmount <== zAccountUtxoInPrpAmount;
    ammV1RC.zAccountUtxoInZoneId <== zAccountUtxoInZoneId;
    ammV1RC.zAccountUtxoInNetworkId <== zAccountUtxoInNetworkId;
    ammV1RC.zAccountUtxoInExpiryTime <== zAccountUtxoInExpiryTime;
    ammV1RC.zAccountUtxoInNonce <== zAccountUtxoInNonce;
    ammV1RC.zAccountUtxoInTotalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    ammV1RC.zAccountUtxoInCreateTime <== zAccountUtxoInCreateTime;
    ammV1RC.zAccountUtxoInRootSpendPubKey <== zAccountUtxoInRootSpendPubKey;
    ammV1RC.zAccountUtxoInReadPubKey <== zAccountUtxoInReadPubKey;
    ammV1RC.zAccountUtxoInNullifierPubKey <== zAccountUtxoInNullifierPubKey;
    ammV1RC.zAccountUtxoInSpendPrivKey <== zAccountUtxoInSpendPrivKey;
    ammV1RC.zAccountUtxoInNullifierPrivKey <== zAccountUtxoInNullifierPrivKey;
    ammV1RC.zAccountUtxoInMasterEOA <== zAccountUtxoInMasterEOA;
    ammV1RC.zAccountUtxoInSpendKeyRandom <== zAccountUtxoInSpendKeyRandom;
    ammV1RC.zAccountUtxoInCommitment <== zAccountUtxoInCommitment;
    ammV1RC.zAccountUtxoInNullifier <== zAccountUtxoInNullifier;
    ammV1RC.zAccountUtxoInMerkleTreeSelector <== zAccountUtxoInMerkleTreeSelector;
    ammV1RC.zAccountUtxoInPathIndices <== zAccountUtxoInPathIndices;
    ammV1RC.zAccountUtxoInPathElements <== zAccountUtxoInPathElements;

    ammV1RC.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    ammV1RC.zAccountUtxoOutPrpAmount <== zAccountUtxoOutPrpAmount;
    ammV1RC.zAccountUtxoOutSpendKeyRandom <== zAccountUtxoOutSpendKeyRandom;
    ammV1RC.zAccountUtxoOutCommitment <== zAccountUtxoOutCommitment;

    ammV1RC.zAccountBlackListLeaf <== zAccountBlackListLeaf;
    ammV1RC.zAccountBlackListMerkleRoot <== zAccountBlackListMerkleRoot;
    ammV1RC.zAccountBlackListPathElements <== zAccountBlackListPathElements;

    ammV1RC.zZoneOriginZoneIDs <== zZoneOriginZoneIDs;
    ammV1RC.zZoneTargetZoneIDs <== zZoneTargetZoneIDs;
    ammV1RC.zZoneNetworkIDsBitMap <== zZoneNetworkIDsBitMap;
    ammV1RC.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    ammV1RC.zZoneKycExpiryTime <== zZoneKycExpiryTime;
    ammV1RC.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    ammV1RC.zZoneDepositMaxAmount <== zZoneDepositMaxAmount;
    ammV1RC.zZoneWithrawMaxAmount <== zZoneWithrawMaxAmount;
    ammV1RC.zZoneInternalMaxAmount <== zZoneInternalMaxAmount;
    ammV1RC.zZoneMerkleRoot <== zZoneMerkleRoot;
    ammV1RC.zZonePathElements <== zZonePathElements;
    ammV1RC.zZonePathIndices <== zZonePathIndices;
    ammV1RC.zZoneEdDsaPubKey <== zZoneEdDsaPubKey;
    ammV1RC.zZoneZAccountIDsBlackList <== zZoneZAccountIDsBlackList;
    ammV1RC.zZoneMaximumAmountPerTimePeriod <== zZoneMaximumAmountPerTimePeriod;
    ammV1RC.zZoneTimePeriodPerMaximumAmount <== zZoneTimePeriodPerMaximumAmount;
    ammV1RC.zZoneDataEscrowPubKey[0] <== zZoneDataEscrowPubKey[0];
    ammV1RC.zZoneDataEscrowPubKey[1] <== zZoneDataEscrowPubKey[1];
    ammV1RC.zZoneSealing <== zZoneSealing;

    ammV1RC.zNetworkId <== zNetworkId;
    ammV1RC.zNetworkChainId <== zNetworkChainId;
    ammV1RC.zNetworkIDsBitMap <== zNetworkIDsBitMap;
    ammV1RC.zNetworkTreeMerkleRoot <== zNetworkTreeMerkleRoot;
    ammV1RC.zNetworkTreePathElements <== zNetworkTreePathElements;
    ammV1RC.zNetworkTreePathIndices <== zNetworkTreePathIndices;

    ammV1RC.daoDataEscrowPubKey <== daoDataEscrowPubKey;
    ammV1RC.forTxReward <== forTxReward;
    ammV1RC.forUtxoReward <== forUtxoReward;
    ammV1RC.forDepositReward <== forDepositReward;

    ammV1RC.trustProvidersMerkleRoot <== trustProvidersMerkleRoot;
    ammV1RC.staticTreeMerkleRoot <== staticTreeMerkleRoot;
    ammV1RC.forestMerkleRoot <== forestMerkleRoot;
    ammV1RC.taxiMerkleRoot <== taxiMerkleRoot;
    ammV1RC.busMerkleRoot <== busMerkleRoot;
    ammV1RC.ferryMerkleRoot <== ferryMerkleRoot;

    ammV1RC.salt <== salt;
    ammV1RC.saltHash <== saltHash;
    ammV1RC.magicalConstraint <== magicalConstraint;
}
