//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

// project deps
include "./templates/isNotZero.circom";
include "./templates/kycKytMerkleTreeLeafIdAndRuleInclusionProver.circom";
include "./templates/kycKytNoteInclusionProver.circom";
include "./templates/pubKeyDeriver.circom";
include "./templates/zAccountBlackListLeafInclusionProver.circom";
include "./templates/zAccountNoteHasher.circom";
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

template ZAccountRegitrationV1 ( ZNetworkMerkleTreeDepth,
                                 ZAssetMerkleTreeDepth,
                                 ZAccountBlackListMerkleTreeDepth,
                                 ZZoneMerkleTreeDepth,
                                 KycKytMerkleTreeDepth ) {
    // external data anchoring
    signal input extraInputsHash;  // public

    // zkp amounts (not scaled)
    signal input zkpAmount; // public
    signal input zkpChange; // public

    // zAsset
    signal input zAssetId;
    signal input zAssetToken;
    signal input zAssetTokenId;
    signal input zAssetNetwork;
    signal input zAssetOffset;
    signal input zAssetWeight;
    signal input zAssetScale;
    signal input zAssetMerkleRoot;
    signal input zAssetPathIndex[ZAssetMerkleTreeDepth];
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
    signal input zAccountRootSpendPrivKey;
    signal input zAccountRootSpendPubKey[2]; // public
    signal input zAccountMasterEOA;          // public
    signal input zAccountSpendKeyRandom;
    signal input zAccountCommitment; // public
    signal input zAccountNullifier;  // public

    // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
    signal input zAccountBlackListLeaf;
    signal input zAccountBlackListMerkleRoot;
    signal input zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth];

    // zZone
    signal input zZoneOriginZoneIDs;
    signal input zZoneTargetZoneIDs;
    signal input zZoneNetworkIDsBitMap;
    signal input zZoneKycKytMerkleTreeLeafIDsAndRulesList;
    signal input zZoneKycExpiryTime;
    signal input zZoneKytExpiryTime;
    signal input zZoneDepositMaxAmount;
    signal input zZoneWithrawMaxAmount;
    signal input zZoneInternalMaxAmount;
    signal input zZoneMerkleRoot;
    signal input zZonePathElements[ZZoneMerkleTreeDepth];
    signal input zZonePathIndex[ZZoneMerkleTreeDepth];
    signal input zZoneEdDsaPubKey[2];
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;

    // KYC
    signal input kycEdDsaPubKey[2];
    signal input kycEdDsaPubKeyExpiryTime;
    signal input kycKytMerkleRoot;
    signal input kycPathElements[KycKytMerkleTreeDepth];
    signal input kycPathIndex[KycKytMerkleTreeDepth];
    signal input kycMerkleTreeLeafIDsAndRulesOffset;
    // signed message
    signal input kycSignedMessagePackageType;         // 1 - KYC, TODO: require
    signal input kycSignedMessageTimestamp;
    signal input kycSignedMessageSender;              // 0
    signal input kycSignedMessageReceiver;            // 0
    signal input kycSignedMessageToken;               // 0
    signal input kycSignedMessageSessionIdHex;
    signal input kycSignedMessageRuleId;
    signal input kycSignedMessageAmount;              // 0
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
    signal input zNetworkTreePathIndex[ZNetworkMerkleTreeDepth];

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
    // 5) kycKytMerkleRoot
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
        zAssetNoteInclusionProver.pathIndex[i] <== zAssetPathIndex[i];
        zAssetNoteInclusionProver.pathElements[i] <== zAssetPathElements[i];
    }

    // [2] - Verify input 'zAccount UTXO input'
    component zAccountRootSpendPubKeyCheck = BabyPbk();
    zAccountRootSpendPubKeyCheck.in <== zAccountRootSpendPrivKey;

    // verify root spend key
    zAccountRootSpendPubKey[0] === zAccountRootSpendPubKeyCheck.Ax;
    zAccountRootSpendPubKey[1] === zAccountRootSpendPubKeyCheck.Ay;

    // derive spend pub key
    component zAccountSpendPubKeyDeriver = PubKeyDeriver();
    zAccountSpendPubKeyDeriver.rootPubKey[0] <== zAccountRootSpendPubKey[0];
    zAccountSpendPubKeyDeriver.rootPubKey[1] <== zAccountRootSpendPubKey[1];
    zAccountSpendPubKeyDeriver.random <== zAccountSpendKeyRandom; // random generated by sender

    component zAccountNoteHasher = ZAccountNoteHasher();
    zAccountNoteHasher.spendPubKey[0] <== zAccountSpendPubKeyDeriver.derivedPubKey[0];
    zAccountNoteHasher.spendPubKey[1] <== zAccountSpendPubKeyDeriver.derivedPubKey[1];
    zAccountNoteHasher.rootSpendPubKey[0] <== zAccountRootSpendPubKey[0];
    zAccountNoteHasher.rootSpendPubKey[1] <== zAccountRootSpendPubKey[1];
    zAccountNoteHasher.masterEOA <== zAccountMasterEOA;
    zAccountNoteHasher.id <== zAccountId;
    zAccountNoteHasher.amountZkp <== zAccountZkpAmount;
    zAccountNoteHasher.amountPrp <== zAccountPrpAmount;
    zAccountNoteHasher.zoneId <== zAccountZoneId;
    zAccountNoteHasher.expiryTime <== zAccountExpiryTime;
    zAccountNoteHasher.nonce <== zAccountNonce;
    zAccountNoteHasher.totalAmountPerTimePeriod <== zAccountTotalAmountPerTimePeriod;
    zAccountNoteHasher.createTime <== zAccountCreateTime;
    zAccountNoteHasher.networkId <== zAccountNetworkId;

    // verify required values
    zAccountTotalAmountPerTimePeriod === 0;

    // verify zNetworkId is equal to zAccountNetworkId (anchoring)
    zAccountNetworkId === zNetworkId;

    // verify expireTime
    zAccountExpiryTime === zAccountCreateTime + zZoneKycExpiryTime;

    // [3] - verify ZKP & PRP balance
    assert(zAccountZkpAmount < 2**254);
    // prp amount decided by the protocol on smart contract level
    assert(zAccountPrpAmount < 2**64);

    var zAssetScaleFactor = 10**zAssetScale;
    signal zkpScaledAmount;
    zkpScaledAmount <-- zkpAmount \ zAssetScaleFactor;

    // verify scaled zkp amount
    zkpScaledAmount === zAccountZkpAmount;

    signal zkpAmountRestored;
    zkpAmountRestored <-- zkpScaledAmount * zAssetScaleFactor;

    // verify zkp change
    zkpChange === zkpAmount - zkpAmountRestored;

    // [4] - Verify zAccountUtxo commitment
    component zAccountUtxoOutHasherProver = ForceEqualIfEnabled();
    zAccountUtxoOutHasherProver.in[0] <== zAccountCommitment;
    zAccountUtxoOutHasherProver.in[1] <== zAccountNoteHasher.out;
    zAccountUtxoOutHasherProver.enabled <== zAccountCommitment;

    // [5] - Verify zAccount nullifier
    component zAccountNullifierHasher = Poseidon(4);
    zAccountNullifierHasher.inputs[0] <== zAccountId;
    zAccountNullifierHasher.inputs[1] <== zAccountZoneId;
    zAccountNullifierHasher.inputs[2] <== zAccountNetworkId;
    zAccountNullifierHasher.inputs[3] <== zAccountRootSpendPrivKey;

    component zAccountNullifierHasherProver = ForceEqualIfEnabled();
    zAccountNullifierHasherProver.in[0] <== zAccountNullifier;
    zAccountNullifierHasherProver.in[1] <== zAccountNullifierHasher.out;
    zAccountNullifierHasherProver.enabled <== zAccountNullifier;

    // [6] - Verify zAccoutId exclusion proof
    component zAccountBlackListInlcusionProver = ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.zAccountId <== zAccountId;
    zAccountBlackListInlcusionProver.leaf <== zAccountBlackListLeaf;
    zAccountBlackListInlcusionProver.merkleRoot <== zAccountBlackListMerkleRoot;
    for (var j = 0; j < ZZoneMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== zAccountBlackListPathElements[j];
    }

    // [7] - Verify KYT signature
    component kycSignedMessageHashInternal = Poseidon(8);

    kycSignedMessageHashInternal.inputs[0] <== kycSignedMessagePackageType; // TODO: FIXME - equal to 1
    kycSignedMessageHashInternal.inputs[1] <== kycSignedMessageTimestamp;
    kycSignedMessageHashInternal.inputs[2] <== kycSignedMessageSender; // TODO: should we check MasterEOA === sender ?
    kycSignedMessageHashInternal.inputs[3] <== kycSignedMessageReceiver;
    kycSignedMessageHashInternal.inputs[4] <== kycSignedMessageToken;
    kycSignedMessageHashInternal.inputs[5] <== kycSignedMessageSessionIdHex;
    kycSignedMessageHashInternal.inputs[6] <== kycSignedMessageRuleId;
    kycSignedMessageHashInternal.inputs[7] <== kycSignedMessageAmount;

    // verify required values
    kycSignedMessageReceiver === 0;
    kycSignedMessageToken === 0;
    kycSignedMessageAmount === 0;

    component kycSignatureVerifier = EdDSAPoseidonVerifier();
    kycSignatureVerifier.enabled <== kycKytMerkleRoot;
    kycSignatureVerifier.Ax <== kycEdDsaPubKey[0];
    kycSignatureVerifier.Ay <== kycEdDsaPubKey[1];
    kycSignatureVerifier.S <== kycSignature[0];
    kycSignatureVerifier.R8x <== kycSignature[1];
    kycSignatureVerifier.R8y <== kycSignature[2];

    kycSignatureVerifier.M <== kycSignedMessageHashInternal.out;

    // check if enabled
    component iskycSignedMessageHashIsEqualEnabled = IsNotZero();
    iskycSignedMessageHashIsEqualEnabled.in <== kycKytMerkleRoot;

    // verify kyc-hash
    component kycSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kycSignedMessageHashIsEqual.enabled <== iskycSignedMessageHashIsEqualEnabled.out;
    kycSignedMessageHashIsEqual.in[0] <== kycSignedMessageHash;
    kycSignedMessageHashIsEqual.in[1] <== kycSignedMessageHashInternal.out;

    // [8] - Verify kycEdDSA public key membership
    component kycKycNoteInclusionProver = KycKytNoteInclusionProver(KycKytMerkleTreeDepth);
    kycKycNoteInclusionProver.enabled <== kycKytMerkleRoot;
    kycKycNoteInclusionProver.root <== kycKytMerkleRoot;
    kycKycNoteInclusionProver.key[0] <== kycEdDsaPubKey[0];
    kycKycNoteInclusionProver.key[1] <== kycEdDsaPubKey[1];
    kycKycNoteInclusionProver.expiryTime <== kycEdDsaPubKeyExpiryTime;
    for (var j=0; j< KycKytMerkleTreeDepth; j++) {
        kycKycNoteInclusionProver.pathIndex[j] <== kycPathIndex[j];
        kycKycNoteInclusionProver.pathElements[j] <== kycPathElements[j];
    }

    // [9] - Verify kyc leaf-id & rule allowed in zZone - required if deposit or withdraw != 0
    component b2nLeafId = Bits2Num(KycKytMerkleTreeDepth);
    for (var j = 0; j < KycKytMerkleTreeDepth; j++) {
        b2nLeafId.in[j] <== kycPathIndex[j];
    }
    component kycLeafIdAndRuleInclusionProver = KycKytMerkleTreeLeafIDAndRuleInclusionProver();
    kycLeafIdAndRuleInclusionProver.enabled <== kycKytMerkleRoot;
    kycLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kycLeafIdAndRuleInclusionProver.rule <== kycSignedMessageRuleId;
    kycLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneKycKytMerkleTreeLeafIDsAndRulesList;
    kycLeafIdAndRuleInclusionProver.offset <== kycMerkleTreeLeafIDsAndRulesOffset;

    // [10] - Verify zZone membership
    component zZoneNoteHasher = ZZoneNoteHasher();
    zZoneNoteHasher.zoneId <== zAccountZoneId;
    zZoneNoteHasher.edDsaPubKey[0] <== zZoneEdDsaPubKey[0];
    zZoneNoteHasher.edDsaPubKey[1] <== zZoneEdDsaPubKey[1];
    zZoneNoteHasher.originZoneIDs <== zZoneOriginZoneIDs;
    zZoneNoteHasher.targetZoneIDs <== zZoneTargetZoneIDs;
    zZoneNoteHasher.networkIDsBitMap <== zZoneNetworkIDsBitMap;
    zZoneNoteHasher.kycKytMerkleTreeLeafIDsAndRulesList <== zZoneKycKytMerkleTreeLeafIDsAndRulesList;
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
        zZoneInclusionProver.pathIndices[j] <== zZonePathIndex[j];
        zZoneInclusionProver.pathElements[j] <== zZonePathElements[j];
    }

    // [11] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [12] - Verify zNetwork's membership
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
        zNetworkNoteInclusionProver.pathIndex[i] <== zNetworkTreePathIndex[i];
        zNetworkNoteInclusionProver.pathElements[i] <== zNetworkTreePathElements[i];
    }

    // [13] - Verify static-merkle-root
    component staticTreeMerkleRootVerifier = Poseidon(5);
    staticTreeMerkleRootVerifier.inputs[0] <== zAssetMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[1] <== zAccountBlackListMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[2] <== zNetworkTreeMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[3] <== zZoneMerkleRoot;
    staticTreeMerkleRootVerifier.inputs[4] <== kycKytMerkleRoot;

    // verify computed root against provided one
    component isEqualStaticTreeMerkleRoot = ForceEqualIfEnabled();
    isEqualStaticTreeMerkleRoot.in[0] <== staticTreeMerkleRootVerifier.out;
    isEqualStaticTreeMerkleRoot.in[1] <== staticTreeMerkleRoot;
    isEqualStaticTreeMerkleRoot.enabled <== staticTreeMerkleRoot;

    // [14] - Verify forest-merkle-roots
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

    // [15] - Verify salt
    component saltVerify = Poseidon(1);
    saltVerify.inputs[0] <== salt;

    component isEqualSalt = ForceEqualIfEnabled();
    isEqualSalt.in[0] <== saltVerify.out;
    isEqualSalt.in[1] <== saltHash;
    isEqualSalt.enabled <== saltHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [16] - Magical Contraint check ////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;
}
