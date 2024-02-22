//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

// project deps
include "./templates/balanceChecker.circom";
include "./templates/isNotZero.circom";
include "./templates/trustProvidersMerkleTreeLeafIdAndRuleInclusionProver.circom";
include "./templates/trustProvidersNoteInclusionProver.circom";
include "./templates/pubKeyDeriver.circom";
include "./templates/zAccountBlackListLeafInclusionProver.circom";
include "./templates/zAccountNoteHasher.circom";
include "./templates/zAccountNoteInclusionProver.circom";
include "./templates/zAccountNullifierHasher.circom";
include "./templates/zAssetChecker.circom";
include "./templates/zAssetNoteInclusionProver.circom";
include "./templates/zNetworkNoteInclusionProver.circom";
include "./templates/zZoneNoteHasher.circom";
include "./templates/zZoneNoteInclusionProver.circom";
include "./templates/zZoneZAccountBlackListExclusionProver.circom";

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

include "./zAccountRenewalV1RangeCheck.circom";

template ZAccountRenewalV1 ( UtxoLeftMerkleTreeDepth,
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
    // external data anchoring
    signal input extraInputsHash;  // public

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
    signal input zZoneWithrawMaxAmount;
    signal input zZoneInternalMaxAmount;
    signal input zZoneMerkleRoot;
    signal input zZonePathElements[ZZoneMerkleTreeDepth];
    signal input zZonePathIndices[ZZoneMerkleTreeDepth];
    signal input zZoneEdDsaPubKey[2];
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;

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

    // verify zkp-token
    zAssetChecker.isZkpToken === 1;

    // [3] - Zkp balance
    component totalBalanceChecker = BalanceChecker();
    totalBalanceChecker.isZkpToken <== zAssetChecker.isZkpToken;
    totalBalanceChecker.depositAmount <== 0;
    totalBalanceChecker.depositChange <== 0;
    totalBalanceChecker.withdrawAmount <== 0;
    totalBalanceChecker.withdrawChange <== 0;
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.donatedAmountZkp <== 0;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== 0;
    totalBalanceChecker.totalUtxoOutAmount <== 0;
    totalBalanceChecker.zAssetWeight <== zAssetWeight;
    totalBalanceChecker.zAssetScale <== zAssetScale;
    totalBalanceChecker.zAssetScaleZkp <== zAssetScale;

    // [4] - Verify input 'zAccount UTXO input'
    component zAccountUtxoInRootSpendPubKeyCheck = BabyPbk();
    zAccountUtxoInRootSpendPubKeyCheck.in <== zAccountUtxoInRootSpendPrivKey;

    // verify root spend key
    zAccountUtxoInRootSpendPubKey[0] === zAccountUtxoInRootSpendPubKeyCheck.Ax;
    zAccountUtxoInRootSpendPubKey[1] === zAccountUtxoInRootSpendPubKeyCheck.Ay;

    // derive spend pub key
    component zAccountUtxoInSpendPubKeyDeriver = PubKeyDeriver();
    zAccountUtxoInSpendPubKeyDeriver.rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoInSpendPubKeyDeriver.rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoInSpendPubKeyDeriver.random <== zAccountUtxoInSpendKeyRandom; // random generated by sender

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
    component zAccountUtxoInNullifierHasher = ZAccountNullifierHasher();
    zAccountUtxoInNullifierHasher.privKey <== zAccountUtxoInNullifierPrivKey; // r * RootPrivKey
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
    zAccountUtxoOutNoteHasher.amountZkp <== zAccountUtxoInZkpAmount;
    zAccountUtxoOutNoteHasher.amountPrp <== zAccountUtxoInPrpAmount;
    zAccountUtxoOutNoteHasher.zoneId <== zAccountUtxoInZoneId;
    zAccountUtxoOutNoteHasher.expiryTime <== zAccountUtxoOutExpiryTime;
    zAccountUtxoOutNoteHasher.nonce <== zAccountUtxoInNonce + 1;
    zAccountUtxoOutNoteHasher.totalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zAccountUtxoOutNoteHasher.createTime <== zAccountUtxoOutCreateTime;
    zAccountUtxoOutNoteHasher.networkId <== zAccountUtxoInNetworkId;

    // verify expiry time
    zAccountUtxoOutExpiryTime === zAccountUtxoOutCreateTime + zZoneKycExpiryTime;

    // [10] - Verify zAccountUtxoOut commitment
    component zAccountUtxoOutHasherProver = ForceEqualIfEnabled();
    zAccountUtxoOutHasherProver.in[0] <== zAccountUtxoOutCommitment;
    zAccountUtxoOutHasherProver.in[1] <== zAccountUtxoOutNoteHasher.out;
    zAccountUtxoOutHasherProver.enabled <== zAccountUtxoOutCommitment;

    // [11] - Verify KYT signature
    component kycSignedMessageHashInternal = Poseidon(7);

    kycSignedMessageHashInternal.inputs[0] <== kycSignedMessagePackageType;
    kycSignedMessageHashInternal.inputs[1] <== kycSignedMessageTimestamp;
    kycSignedMessageHashInternal.inputs[2] <== kycSignedMessageSender;
    kycSignedMessageHashInternal.inputs[3] <== kycSignedMessageReceiver;
    kycSignedMessageHashInternal.inputs[4] <== kycSignedMessageSessionId;
    kycSignedMessageHashInternal.inputs[5] <== kycSignedMessageRuleId;
    kycSignedMessageHashInternal.inputs[6] <== kycSignedMessageSigner;

    // verify required values
    kycSignedMessagePackageType === 1; // KYC pkg type
    kycSignedMessageSender === zAccountUtxoInMasterEOA;
    kycSignedMessageSender === kycSignedMessageSigner;

    component kycSignatureVerifier = EdDSAPoseidonVerifier();
    kycSignatureVerifier.enabled <== trustProvidersMerkleRoot;
    kycSignatureVerifier.Ax <== kycEdDsaPubKey[0];
    kycSignatureVerifier.Ay <== kycEdDsaPubKey[1];
    kycSignatureVerifier.S <== kycSignature[0];
    kycSignatureVerifier.R8x <== kycSignature[1];
    kycSignatureVerifier.R8y <== kycSignature[2];

    kycSignatureVerifier.M <== kycSignedMessageHashInternal.out;

    // check if enabled
    component iskycSignedMessageHashIsEqualEnabled = IsNotZero();
    iskycSignedMessageHashIsEqualEnabled.in <== trustProvidersMerkleRoot;

    // verify kyc-hash
    component kycSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kycSignedMessageHashIsEqual.enabled <== iskycSignedMessageHashIsEqualEnabled.out;
    kycSignedMessageHashIsEqual.in[0] <== kycSignedMessageHash;
    kycSignedMessageHashIsEqual.in[1] <== kycSignedMessageHashInternal.out;

    // [12] - Verify kycEdDSA public key membership
    component kycKycNoteInclusionProver = TrustProvidersNoteInclusionProver(TrustProvidersMerkleTreeDepth);
    kycKycNoteInclusionProver.enabled <== iskycSignedMessageHashIsEqualEnabled.out;
    kycKycNoteInclusionProver.root <== trustProvidersMerkleRoot;
    kycKycNoteInclusionProver.key[0] <== kycEdDsaPubKey[0];
    kycKycNoteInclusionProver.key[1] <== kycEdDsaPubKey[1];
    kycKycNoteInclusionProver.expiryTime <== kycEdDsaPubKeyExpiryTime;
    for (var j=0; j< TrustProvidersMerkleTreeDepth; j++) {
        kycKycNoteInclusionProver.pathIndices[j] <== kycPathIndices[j];
        kycKycNoteInclusionProver.pathElements[j] <== kycPathElements[j];
    }

    // [13] - Verify kyc leaf-id & rule allowed in zZone - required if deposit or withdraw != 0
    component b2nLeafId = Bits2Num(TrustProvidersMerkleTreeDepth);
    for (var j = 0; j < TrustProvidersMerkleTreeDepth; j++) {
        b2nLeafId.in[j] <== kycPathIndices[j];
    }
    component kycLeafIdAndRuleInclusionProver = TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver();
    kycLeafIdAndRuleInclusionProver.enabled <== trustProvidersMerkleRoot;
    kycLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kycLeafIdAndRuleInclusionProver.rule <== kycSignedMessageRuleId;
    kycLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    kycLeafIdAndRuleInclusionProver.offset <== kycMerkleTreeLeafIDsAndRulesOffset;

    // [14] - Verify zZone membership
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

    component zZoneInclusionProver = ZZoneNoteInclusionProver(ZZoneMerkleTreeDepth);
    zZoneInclusionProver.zZoneCommitment <== zZoneNoteHasher.out;
    zZoneInclusionProver.root <== zZoneMerkleRoot;
    for (var j=0; j < ZZoneMerkleTreeDepth; j++) {
        zZoneInclusionProver.pathIndices[j] <== zZonePathIndices[j];
        zZoneInclusionProver.pathElements[j] <== zZonePathElements[j];
    }

    // [15] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountUtxoInId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [16] - Verify zNetwork's membership
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

    // [17] - Verify static-merkle-root
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

    // [18] - Verify forest-merkle-roots
    component forestTreeMerkleRootVerifier = Poseidon(4);
    forestTreeMerkleRootVerifier.inputs[0] <== taxiMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[1] <== busMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[2] <== ferryMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[3] <== staticTreeMerkleRoot;

    // verify computed root against provided one
    component isEqualForestTreeMerkleRoot = ForceEqualIfEnabled();
    isEqualForestTreeMerkleRoot.in[0] <== forestTreeMerkleRootVerifier.out;
    isEqualForestTreeMerkleRoot.in[1] <== forestMerkleRoot;
    isEqualForestTreeMerkleRoot.enabled <== forestMerkleRoot;

    // [19] - Verify salt
    component saltVerify = Poseidon(1);
    saltVerify.inputs[0] <== salt;

    component isEqualSalt = ForceEqualIfEnabled();
    isEqualSalt.in[0] <== saltVerify.out;
    isEqualSalt.in[1] <== saltHash;
    isEqualSalt.enabled <== saltHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [20] - Magical Contraint check ////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [21] - Range Check ////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component zAccountRenewalRC = ZAccountRenewalRangeCheck(UtxoLeftMerkleTreeDepth,
                                                                 UtxoMiddleMerkleTreeDepth,
                                                                 ZNetworkMerkleTreeDepth,
                                                                 ZAssetMerkleTreeDepth,
                                                                 ZAccountBlackListMerkleTreeDepth,
                                                                 ZZoneMerkleTreeDepth,
                                                                 TrustProvidersMerkleTreeDepth);

    zAccountRenewalRC.extraInputsHash <== extraInputsHash;

    zAccountRenewalRC.chargedAmountZkp <== chargedAmountZkp;

    zAccountRenewalRC.zAssetId <== zAssetId;
    zAccountRenewalRC.zAssetToken <== zAssetToken;
    zAccountRenewalRC.zAssetTokenId <== zAssetTokenId;
    zAccountRenewalRC.zAssetNetwork <== zAssetNetwork;
    zAccountRenewalRC.zAssetOffset <== zAssetOffset;
    zAccountRenewalRC.zAssetWeight <== zAssetWeight;
    zAccountRenewalRC.zAssetScale <== zAssetScale;
    zAccountRenewalRC.zAssetMerkleRoot <== zAssetMerkleRoot;
    zAccountRenewalRC.zAssetPathIndices <== zAssetPathIndices;
    zAccountRenewalRC.zAssetPathElements <== zAssetPathElements;

    zAccountRenewalRC.zAccountUtxoInId <== zAccountUtxoInId;
    zAccountRenewalRC.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    zAccountRenewalRC.zAccountUtxoInPrpAmount <== zAccountUtxoInPrpAmount;
    zAccountRenewalRC.zAccountUtxoInZoneId <== zAccountUtxoInZoneId;
    zAccountRenewalRC.zAccountUtxoInNetworkId <== zAccountUtxoInNetworkId;
    zAccountRenewalRC.zAccountUtxoInExpiryTime <== zAccountUtxoInExpiryTime;
    zAccountRenewalRC.zAccountUtxoInNonce <== zAccountUtxoInNonce;
    zAccountRenewalRC.zAccountUtxoInTotalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zAccountRenewalRC.zAccountUtxoInCreateTime <== zAccountUtxoInCreateTime;
    zAccountRenewalRC.zAccountUtxoInRootSpendPrivKey <== zAccountUtxoInRootSpendPrivKey;
    zAccountRenewalRC.zAccountUtxoInRootSpendPubKey <== zAccountUtxoInRootSpendPubKey;
    zAccountRenewalRC.zAccountUtxoInReadPubKey <== zAccountUtxoInReadPubKey;
    zAccountRenewalRC.zAccountUtxoInNullifierPubKey <== zAccountUtxoInNullifierPubKey;
    zAccountRenewalRC.zAccountUtxoInMasterEOA <== zAccountUtxoInMasterEOA;
    zAccountRenewalRC.zAccountUtxoInSpendKeyRandom <== zAccountUtxoInSpendKeyRandom;
    zAccountRenewalRC.zAccountUtxoInNullifierPrivKey <== zAccountUtxoInNullifierPrivKey;
    zAccountRenewalRC.zAccountUtxoInCommitment <== zAccountUtxoInCommitment;
    zAccountRenewalRC.zAccountUtxoInNullifier <== zAccountUtxoInNullifier;
    zAccountRenewalRC.zAccountUtxoInMerkleTreeSelector <== zAccountUtxoInMerkleTreeSelector;
    zAccountRenewalRC.zAccountUtxoInPathIndices <== zAccountUtxoInPathIndices;
    zAccountRenewalRC.zAccountUtxoInPathElements <== zAccountUtxoInPathElements;

    zAccountRenewalRC.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    zAccountRenewalRC.zAccountUtxoOutExpiryTime <== zAccountUtxoOutExpiryTime;
    zAccountRenewalRC.zAccountUtxoOutCreateTime <== zAccountUtxoOutCreateTime;
    zAccountRenewalRC.zAccountUtxoOutSpendKeyRandom <== zAccountUtxoOutSpendKeyRandom;
    zAccountRenewalRC.zAccountUtxoOutCommitment <== zAccountUtxoOutCommitment;

    zAccountRenewalRC.zAccountBlackListLeaf <== zAccountBlackListLeaf;
    zAccountRenewalRC.zAccountBlackListMerkleRoot <== zAccountBlackListMerkleRoot;
    zAccountRenewalRC.zAccountBlackListPathElements <== zAccountBlackListPathElements;

    zAccountRenewalRC.zZoneOriginZoneIDs <== zZoneOriginZoneIDs;
    zAccountRenewalRC.zZoneTargetZoneIDs <== zZoneTargetZoneIDs;
    zAccountRenewalRC.zZoneNetworkIDsBitMap <== zZoneNetworkIDsBitMap;
    zAccountRenewalRC.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zAccountRenewalRC.zZoneKycExpiryTime <== zZoneKycExpiryTime;
    zAccountRenewalRC.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    zAccountRenewalRC.zZoneDepositMaxAmount <== zZoneDepositMaxAmount;
    zAccountRenewalRC.zZoneWithrawMaxAmount <== zZoneWithrawMaxAmount;
    zAccountRenewalRC.zZoneInternalMaxAmount <== zZoneInternalMaxAmount;
    zAccountRenewalRC.zZoneMerkleRoot <== zZoneMerkleRoot;
    zAccountRenewalRC.zZonePathElements <== zZonePathElements;
    zAccountRenewalRC.zZonePathIndices <== zZonePathIndices;
    zAccountRenewalRC.zZoneEdDsaPubKey <== zZoneEdDsaPubKey;
    zAccountRenewalRC.zZoneZAccountIDsBlackList <== zZoneZAccountIDsBlackList;
    zAccountRenewalRC.zZoneMaximumAmountPerTimePeriod <== zZoneMaximumAmountPerTimePeriod;
    zAccountRenewalRC.zZoneTimePeriodPerMaximumAmount <== zZoneTimePeriodPerMaximumAmount;

    zAccountRenewalRC.kycEdDsaPubKey <== kycEdDsaPubKey;
    zAccountRenewalRC.kycEdDsaPubKeyExpiryTime <== kycEdDsaPubKeyExpiryTime;
    zAccountRenewalRC.trustProvidersMerkleRoot <== trustProvidersMerkleRoot;
    zAccountRenewalRC.kycPathElements <== kycPathElements;
    zAccountRenewalRC.kycPathIndices <== kycPathIndices;
    zAccountRenewalRC.kycMerkleTreeLeafIDsAndRulesOffset <== kycMerkleTreeLeafIDsAndRulesOffset;
    zAccountRenewalRC.kycSignedMessagePackageType <== kycSignedMessagePackageType;
    zAccountRenewalRC.kycSignedMessageTimestamp <== kycSignedMessageTimestamp;
    zAccountRenewalRC.kycSignedMessageSender <== kycSignedMessageSender;
    zAccountRenewalRC.kycSignedMessageReceiver <== kycSignedMessageReceiver;
    zAccountRenewalRC.kycSignedMessageSessionId <== kycSignedMessageSessionId;
    zAccountRenewalRC.kycSignedMessageRuleId <== kycSignedMessageRuleId;
    zAccountRenewalRC.kycSignedMessageSigner <== kycSignedMessageSigner;
    zAccountRenewalRC.kycSignedMessageHash <== kycSignedMessageHash;
    zAccountRenewalRC.kycSignature <== kycSignature;

    zAccountRenewalRC.zNetworkId <== zNetworkId;
    zAccountRenewalRC.zNetworkChainId <== zNetworkChainId;
    zAccountRenewalRC.zNetworkIDsBitMap <== zNetworkIDsBitMap;
    zAccountRenewalRC.zNetworkTreeMerkleRoot <== zNetworkTreeMerkleRoot;
    zAccountRenewalRC.zNetworkTreePathElements <== zNetworkTreePathElements;
    zAccountRenewalRC.zNetworkTreePathIndices <== zNetworkTreePathIndices;

    zAccountRenewalRC.daoDataEscrowPubKey <== daoDataEscrowPubKey;
    zAccountRenewalRC.forTxReward <== forTxReward;
    zAccountRenewalRC.forUtxoReward <== forUtxoReward;
    zAccountRenewalRC.forDepositReward <== forDepositReward;

    zAccountRenewalRC.staticTreeMerkleRoot <== staticTreeMerkleRoot;

    zAccountRenewalRC.forestMerkleRoot <== forestMerkleRoot;
    zAccountRenewalRC.taxiMerkleRoot <== taxiMerkleRoot;
    zAccountRenewalRC.busMerkleRoot <== busMerkleRoot;
    zAccountRenewalRC.ferryMerkleRoot <== ferryMerkleRoot;

    zAccountRenewalRC.salt <== salt;
    zAccountRenewalRC.saltHash <== saltHash;

    zAccountRenewalRC.magicalConstraint <== magicalConstraint;
}
