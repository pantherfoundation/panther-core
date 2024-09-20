//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

// project deps
include "./templates/balanceChecker.circom";
include "./templates/trustProvidersMerkleTreeLeafIDAndRuleInclusionProver.circom";
include "./templates/trustProvidersNoteInclusionProver.circom";
include "./templates/pubKeyDeriver.circom";
include "./templates/zAccountBlackListLeafInclusionProver.circom";
include "./templates/zAccountNoteHasher.circom";
include "./templates/zAssetChecker.circom";
include "./templates/zAssetNoteInclusionProver.circom";
include "./templates/zNetworkNoteInclusionProver.circom";
include "./templates/zZoneNoteHasher.circom";
include "./templates/zZoneNoteInclusionProver.circom";
include "./templates/zZoneZAccountBlackListExclusionProver.circom";
include "./templates/utils.circom";

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template ZAccountRegistrationV1 ( ZNetworkMerkleTreeDepth,
                                  ZAssetMerkleTreeDepth,
                                  ZAccountBlackListMerkleTreeDepth,
                                  ZZoneMerkleTreeDepth,
                                  TrustProvidersMerkleTreeDepth ) {
    // external data anchoring
    signal input extraInputsHash;  // public

    // zkp amounts (not scaled)
    signal input {uint96} addedAmountZkp;   // public
    // output 'protocol + relayer fee in ZKP'
    signal input {uint96} chargedAmountZkp; // public

    // zAsset
    signal input {uint64}          zAssetId;
    signal input {uint168}         zAssetToken;
    signal input {uint252}         zAssetTokenId;
    signal input {uint6}           zAssetNetwork;
    signal input {uint32}          zAssetOffset;
    signal input {uint48}          zAssetWeight;
    signal input {non_zero_uint64} zAssetScale;
    signal input                   zAssetMerkleRoot;
    signal input {binary}          zAssetPathIndices[ZAssetMerkleTreeDepth];
    signal input                   zAssetPathElements[ZAssetMerkleTreeDepth];

    // zAccount
    signal input {uint24}           zAccountId; // public
    signal input {uint64}           zAccountZkpAmount;
    signal input {uint196}          zAccountPrpAmount;
    signal input {uint16}           zAccountZoneId;
    signal input {uint6}            zAccountNetworkId;
    signal input {uint32}           zAccountExpiryTime;
    signal input {uint32}           zAccountNonce;
    signal input {uint96}           zAccountTotalAmountPerTimePeriod;
    signal input {uint32}           zAccountCreateTime;
    signal input {sub_order_bj_p}   zAccountRootSpendPubKey[2]; // public
    signal input {sub_order_bj_p}   zAccountReadPubKey[2];      // public
    signal input {sub_order_bj_p}   zAccountNullifierPubKey[2]; // public
    signal input {uint160}          zAccountMasterEOA;          // public
    signal input {sub_order_bj_sf}  zAccountRootSpendPrivKey;
    signal input {sub_order_bj_sf}  zAccountReadPrivKey;
    signal input {sub_order_bj_sf}  zAccountNullifierPrivKey;
    signal input {sub_order_bj_sf}  zAccountSpendKeyRandom;
    signal input {external}         zAccountNullifier;  // public
    signal input {external}         zAccountCommitment; // public

    // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
    signal input zAccountBlackListLeaf;
    signal input zAccountBlackListMerkleRoot;
    signal input zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth];

    // zZone
    signal input {uint16}          zZoneOriginZoneIDs;
    signal input {uint16}          zZoneTargetZoneIDs;
    signal input {uint64}          zZoneNetworkIDsBitMap;
    signal input {uint240}         zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input {uint32}          zZoneKycExpiryTime;
    signal input {uint32}          zZoneKytExpiryTime;
    signal input {uint96}          zZoneDepositMaxAmount;
    signal input {uint96}          zZoneWithdrawMaxAmount;
    signal input {uint96}          zZoneInternalMaxAmount;
    signal input                   zZoneMerkleRoot;
    signal input                   zZonePathElements[ZZoneMerkleTreeDepth];
    signal input {binary}          zZonePathIndices[ZZoneMerkleTreeDepth];
    signal input {sub_order_bj_p}  zZoneEdDsaPubKey[2];
    signal input {uint240}         zZoneZAccountIDsBlackList;
    signal input {uint96}          zZoneMaximumAmountPerTimePeriod;
    signal input {uint32}          zZoneTimePeriodPerMaximumAmount;
    signal input {sub_order_bj_p}  zZoneDataEscrowPubKey[2];
    signal input {binary}          zZoneSealing;

    // KYC
    signal input {sub_order_bj_p} kycEdDsaPubKey[2];
    signal input {uint32}         kycEdDsaPubKeyExpiryTime;
    signal input                  trustProvidersMerkleRoot;                       // used both for kytSignature, DataEscrow, DaoDataEscrow
    signal input                  kycPathElements[TrustProvidersMerkleTreeDepth];
    signal input {binary}         kycPathIndices[TrustProvidersMerkleTreeDepth];
    signal input {uint4}          kycMerkleTreeLeafIDsAndRulesOffset;     // used for both cases of deposit & withdraw
    // signed message
    signal input           kycSignedMessagePackageType;         // 1 - KYC
    signal input           kycSignedMessageTimestamp;
    signal input           kycSignedMessageSender;              // 0
    signal input           kycSignedMessageReceiver;            // 0
    signal input           kycSignedMessageSessionId;
    signal input {uint8}   kycSignedMessageRuleId;
    signal input {uint160} kycSignedMessageSigner;
    signal input           kycSignedMessageHash;                // public
    signal input           kycSignature[3];                     // S,R8x,R8y

    // zNetworks tree
    // network parameters:
    // 1) is-active - 1 bit (circuit will set it to TRUE ALWAYS)
    // 2) network-id - 6 bit
    // 3) rewards params - all of them: forTxReward, forUtxoReward, forDepositReward
    // 4) daoDataEscrowPubKey[2]
    signal input {uint6}    zNetworkId;
    signal input {external} zNetworkChainId; // public
    signal input {uint64}   zNetworkIDsBitMap;
    signal input            zNetworkTreeMerkleRoot;
    signal input            zNetworkTreePathElements[ZNetworkMerkleTreeDepth];
    signal input {binary}   zNetworkTreePathIndices[ZNetworkMerkleTreeDepth];

    signal input {sub_order_bj_p}   daoDataEscrowPubKey[2];
    signal input {uint40}           forTxReward;
    signal input {uint40}           forUtxoReward;
    signal input {uint40}           forDepositReward;

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
    var IGNORE_CONSTANT = NonActive();
    var IGNORE_PUBLIC = NonActive();
    var IGNORE_ANCHORED = NonActive();
    var IGNORE_CHECKED_IN_CIRCOMLIB = NonActive();
    var ACTIVE = Active();
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

    // verify zkp-token
    zAssetId === ZkpToken(); // ZKP is zero

    // [2] - Verify input 'zAccount UTXO input'
    component zAccountRootSpendPubKeyCheck = BabyPbk();
    zAccountRootSpendPubKeyCheck.in <== zAccountRootSpendPrivKey;

    // verify root spend key
    zAccountRootSpendPubKey[0] === zAccountRootSpendPubKeyCheck.Ax;
    zAccountRootSpendPubKey[1] === zAccountRootSpendPubKeyCheck.Ay;

    // verify reading key
    component zAccountReadPubKeyChecker = BabyPbk();
    zAccountReadPubKeyChecker.in <== zAccountReadPrivKey;
    zAccountReadPubKeyChecker.Ax === zAccountReadPubKey[0];
    zAccountReadPubKeyChecker.Ay === zAccountReadPubKey[1];

    // verify nullifier key
    component zAccountNullifierPubKeyChecker = BabyPbk();
    zAccountNullifierPubKeyChecker.in <== zAccountNullifierPrivKey;
    zAccountNullifierPubKeyChecker.Ax === zAccountNullifierPubKey[0];
    zAccountNullifierPubKeyChecker.Ay === zAccountNullifierPubKey[1];

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
    zAccountNoteHasher.readPubKey[0] <== zAccountReadPubKey[0];
    zAccountNoteHasher.readPubKey[1] <== zAccountReadPubKey[1];
    zAccountNoteHasher.nullifierPubKey[0] <== zAccountNullifierPubKey[0];
    zAccountNoteHasher.nullifierPubKey[1] <== zAccountNullifierPubKey[1];
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
    zAccountNonce === 0;
    zAccountPrpAmount === 0;

    // verify zNetworkId is equal to zAccountNetworkId (anchoring)
    zAccountNetworkId === zNetworkId;

    // verify expireTime
    zAccountExpiryTime === zAccountCreateTime + zZoneKycExpiryTime;

    // [3] - verify ZKP & PRP balance
    // zkp amount, range-checked since zkpAmount is public signal, and zAssetScale controlled by smart-contracts
    assert(0 <= zAccountZkpAmount < 2**252);
    // prp amount decided by the protocol on smart contract level - range is checked since it is public signal
    assert(0 <= zAccountPrpAmount < 2**64);

    // verify zAsset
    component zAssetChecker = ZAssetChecker();
    zAssetChecker.token <== Uint168Tag(IGNORE_CONSTANT)(0);
    zAssetChecker.tokenId <== Uint252Tag(IGNORE_CONSTANT)(0);
    zAssetChecker.zAssetId <== zAssetId;
    zAssetChecker.zAssetToken <== zAssetToken;
    zAssetChecker.zAssetTokenId <== zAssetTokenId;
    zAssetChecker.zAssetOffset <== zAssetOffset;
    zAssetChecker.depositAmount <== Uint96Tag(IGNORE_CONSTANT)(0);
    zAssetChecker.withdrawAmount <== Uint96Tag(IGNORE_CONSTANT)(0);
    zAssetChecker.utxoZAssetId <== zAssetId;

    // verify zkp-token
    zAssetChecker.isZkpToken === 1;

    // verify Zkp balance
    component totalBalanceChecker = BalanceChecker();
    totalBalanceChecker.isZkpToken <== zAssetChecker.isZkpToken;
    totalBalanceChecker.depositAmount <== Uint96Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.withdrawAmount <== Uint96Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.addedAmountZkp <== addedAmountZkp;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== Uint64Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== Uint70Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.totalUtxoOutAmount <== Uint70Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.zAssetWeight <== zAssetWeight;
    totalBalanceChecker.zAssetScale <== zAssetScale;
    totalBalanceChecker.zAssetScaleZkp <== zAssetScale;
    totalBalanceChecker.kytDepositChargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.kytWithdrawChargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(0);
    totalBalanceChecker.kytInternalChargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(0);

    // verify deposit limit
    assert(zAccountZkpAmount * zAssetWeight <= zZoneDepositMaxAmount);
    component zkpScaledWeithedAmountIsLessThanZZoneDepositMaxAmount;
    zkpScaledWeithedAmountIsLessThanZZoneDepositMaxAmount = LessEqThan(96);
    zkpScaledWeithedAmountIsLessThanZZoneDepositMaxAmount.in[0] <== (zAccountZkpAmount * zAssetWeight);
    zkpScaledWeithedAmountIsLessThanZZoneDepositMaxAmount.in[1] <== zZoneDepositMaxAmount;
    zkpScaledWeithedAmountIsLessThanZZoneDepositMaxAmount.out === 1;

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

    // [7] - Verify KYC signature
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
    kycSignedMessageSender === zAccountMasterEOA;
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

    // [8] - Verify kycEdDSA public key membership
    component trustProvidersNoteInclusionProver = TrustProvidersNoteInclusionProver(TrustProvidersMerkleTreeDepth);
    trustProvidersNoteInclusionProver.enabled <== iskycSignedMessageHashIsEqualEnabled.out;
    trustProvidersNoteInclusionProver.root <== trustProvidersMerkleRoot;
    trustProvidersNoteInclusionProver.key[0] <== kycEdDsaPubKey[0];
    trustProvidersNoteInclusionProver.key[1] <== kycEdDsaPubKey[1];
    trustProvidersNoteInclusionProver.expiryTime <== kycEdDsaPubKeyExpiryTime;
    for (var j=0; j< TrustProvidersMerkleTreeDepth; j++) {
        trustProvidersNoteInclusionProver.pathIndices[j] <== kycPathIndices[j];
        trustProvidersNoteInclusionProver.pathElements[j] <== kycPathElements[j];
    }

    // [9] - Verify kyc leaf-id & rule allowed in zZone - required if deposit or withdraw != 0
    component b2nLeafId = Bits2Num(TrustProvidersMerkleTreeDepth);
    for (var j = 0; j < TrustProvidersMerkleTreeDepth; j++) {
        b2nLeafId.in[j] <== kycPathIndices[j];
    }
    component kycLeafIdAndRuleInclusionProver = TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver();
    kycLeafIdAndRuleInclusionProver.enabled <== trustProvidersMerkleRoot;
    kycLeafIdAndRuleInclusionProver.leafId <== Uint16Tag(ACTIVE)(b2nLeafId.out);
    kycLeafIdAndRuleInclusionProver.rule <== kycSignedMessageRuleId;
    kycLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    kycLeafIdAndRuleInclusionProver.offset <== kycMerkleTreeLeafIDsAndRulesOffset;

    // [10] - Verify zZone membership
    component zZoneNoteHasher = ZZoneNoteHasher();
    zZoneNoteHasher.zoneId <== zAccountZoneId;
    zZoneNoteHasher.edDsaPubKey[0] <== zZoneEdDsaPubKey[0];
    zZoneNoteHasher.edDsaPubKey[1] <== zZoneEdDsaPubKey[1];
    zZoneNoteHasher.originZoneIDs <== zZoneOriginZoneIDs;
    zZoneNoteHasher.targetZoneIDs <== zZoneTargetZoneIDs;
    zZoneNoteHasher.networkIDsBitMap <== zZoneNetworkIDsBitMap;
    zZoneNoteHasher.trustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zZoneNoteHasher.kycExpiryTime <== zZoneKycExpiryTime;
    zZoneNoteHasher.kytExpiryTime <== zZoneKytExpiryTime;
    zZoneNoteHasher.depositMaxAmount <== zZoneDepositMaxAmount;
    zZoneNoteHasher.withdrawMaxAmount <== zZoneWithdrawMaxAmount;
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

    // [11] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [12] - Verify zNetwork's membership
    component zNetworkNoteInclusionProver = ZNetworkNoteInclusionProver(ZNetworkMerkleTreeDepth);
    zNetworkNoteInclusionProver.active <== BinaryOne()(); // ALWAYS ACTIVE
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

    // [13] - Verify static-merkle-root
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

    // [14] - Verify forest-merkle-roots
    component forestTreeMerkleRootVerifier = Poseidon(3);
    forestTreeMerkleRootVerifier.inputs[0] <== taxiMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[1] <== busMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[2] <== ferryMerkleRoot;

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
    // [16] - Magical Constraint check ///////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;
}
