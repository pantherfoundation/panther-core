//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

// project deps
include "./templates/balanceChecker.circom";
include "./templates/dataEscrowElgamalEncryption.circom";
include "./templates/isNotZero.circom";
include "./templates/lessEqThanWhenEnabled.circom";
include "./templates/trustProvidersMerkleTreeLeafIdAndRuleInclusionProver.circom";
include "./templates/trustProvidersNoteInclusionProver.circom";
include "./templates/networkIdInclusionProver.circom";
include "./templates/nullifierHasher.circom";
include "./templates/pubKeyDeriver.circom";
include "./templates/zAccountBlackListLeafInclusionProver.circom";
include "./templates/zAccountNoteHasher.circom";
include "./templates/zAccountNullifierHasher.circom";
include "./templates/rewardsExtended.circom";
include "./templates/utxoNoteHasher.circom";
include "./templates/utxoNoteInclusionProver.circom";
include "./templates/zAccountBlackListLeafInclusionProver.circom";
include "./templates/zAccountNoteHasher.circom";
include "./templates/zAccountNoteInclusionProver.circom";
include "./templates/zAccountNullifierHasher.circom";
include "./templates/zAssetChecker.circom";
include "./templates/zAssetNoteInclusionProver.circom";
include "./templates/zNetworkNoteInclusionProver.circom";
include "./templates/zoneIdInclusionProver.circom";
include "./templates/zZoneNoteHasher.circom";
include "./templates/zZoneNoteInclusionProver.circom";
include "./templates/zZoneZAccountBlackListExclusionProver.circom";
include "./templates/utils.circom";
include "./zTransactionV1RangeCheck.circom";

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";


template ZTransactionV1( nUtxoIn,
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
    var UtxoRightMerkleTreeDepth = UtxoRightMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // Equal to ferry MT size
    var UtxoMerkleTreeDepth = UtxoMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // Bus MT extra levels
    var UtxoMiddleExtraLevels = UtxoMiddleExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, UtxoLeftMerkleTreeDepth);
    // Ferry MT extra levels
    var UtxoRightExtraLevels = UtxoRightExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // zZone data-escrow
    var zZoneDataEscrowEncryptedPoints = ZZoneDataEscrowEncryptedPoints_Fn();
    // main data-escrow
    var dataEscrowScalarSize = DataEscrowScalarSize_Fn( nUtxoIn, nUtxoOut );
    var dataEscrowPointSize = DataEscrowPointSize_Fn( nUtxoOut );
    var dataEscrowEncryptedPoints = DataEscrowEncryptedPoints_Fn( nUtxoIn, nUtxoOut );
    // dao data-escrow
    var daoDataEscrowEncryptedPoints = DaoDataEscrowEncryptedPoints_Fn();
    //////////////////////////////////////////////////////////////////////////////////////////////
    // external data anchoring
    signal input extraInputsHash;  // public

    // tx api
    signal input depositAmount;    // public
    signal input withdrawAmount;   // public
    signal input addedAmountZkp;   // public
    signal input token;            // public - 160 bit ERC20 address - in case of internal tx will be zero
    signal input tokenId;          // public - 256 bit - in case of internal tx will be zero, in case of NTF it is NFT-ID
    signal input utxoZAsset;       // used both for in & out utxo

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

    signal input zAssetIdZkp;
    signal input zAssetTokenZkp;
    signal input zAssetTokenIdZkp;
    signal input zAssetNetworkZkp;
    signal input zAssetOffsetZkp;
    signal input zAssetWeightZkp;
    signal input zAssetScaleZkp;
    signal input zAssetPathIndicesZkp[ZAssetMerkleTreeDepth];
    signal input zAssetPathElementsZkp[ZAssetMerkleTreeDepth];

    // reward computation params
    signal input forTxReward;
    signal input forUtxoReward;
    signal input forDepositReward;

    signal input spendTime; // public

    // input 'zAsset UTXOs'
    // to switch-off:
    //      1) utxoInAmount = 0
    //      2) utxoInSpendPrivKey = 0
    //      3) utxoInSpendKeyRandom = 0
    // switch-off control is used for:
    //      1) deposit only tx
    //      2) deposit & zAccount::zkpAmount
    //      3) deposit & zAccount::zkpAmount & withdraw
    //      4) deposit & withrdaw
    signal input utxoInSpendPrivKey[nUtxoIn];
    signal input utxoInSpendKeyRandom[nUtxoIn];
    signal input utxoInAmount[nUtxoIn];
    signal input utxoInOriginZoneId[nUtxoIn];
    signal input utxoInOriginZoneIdOffset[nUtxoIn];
    signal input utxoInOriginNetworkId[nUtxoIn];
    signal input utxoInTargetNetworkId[nUtxoIn];
    signal input utxoInCreateTime[nUtxoIn];
    signal input utxoInZAccountId[nUtxoIn];
    signal input utxoInMerkleTreeSelector[nUtxoIn][2]; // 2 bits: `00` - Taxi, `01` - Bus, `10` - Ferry
    signal input utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth];
    signal input utxoInPathElements[nUtxoIn][UtxoMerkleTreeDepth];
    signal input utxoInNullifier[nUtxoIn]; // public
    signal input utxoInDataEscrowPubKey[nUtxoIn][2];

    // input 'zAccount UTXO'
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
    signal input zAccountUtxoInMerkleTreeSelector[2]; // 2 bits: `00` - Taxi, `10` - Bus, `01` - Ferry
    signal input zAccountUtxoInPathIndices[UtxoMerkleTreeDepth];
    signal input zAccountUtxoInPathElements[UtxoMerkleTreeDepth];
    signal input zAccountUtxoInNullifier; // public

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
    signal input zZoneDataEscrowEphemeralRandom;
    signal input zZoneDataEscrowEphemeralPubKeyAx; // public
    signal input zZoneDataEscrowEphemeralPubKeyAy;
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;
    signal input zZoneSealing;

    signal input zZoneDataEscrowEncryptedMessageAx[zZoneDataEscrowEncryptedPoints]; // public
    signal input zZoneDataEscrowEncryptedMessageAy[zZoneDataEscrowEncryptedPoints];

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // switch-off control is used for internal tx
    signal input kytEdDsaPubKey[2];
    signal input kytEdDsaPubKeyExpiryTime;
    signal input trustProvidersMerkleRoot;                       // used both for kytSignature, DataEscrow, DaoDataEscrow
    signal input kytPathElements[TrustProvidersMerkleTreeDepth];
    signal input kytPathIndices[TrustProvidersMerkleTreeDepth];
    signal input kytMerkleTreeLeafIDsAndRulesOffset;     // used for both cases of deposit & withdraw
    // deposit case
    signal input kytDepositSignedMessagePackageType;
    signal input kytDepositSignedMessageTimestamp;
    signal input kytDepositSignedMessageSender;         // public
    signal input kytDepositSignedMessageReceiver;       // public
    signal input kytDepositSignedMessageToken;
    signal input kytDepositSignedMessageSessionId;
    signal input kytDepositSignedMessageRuleId;
    signal input kytDepositSignedMessageAmount;
    signal input kytDepositSignedMessageChargedAmountZkp;
    signal input kytDepositSignedMessageSigner;
    signal input kytDepositSignedMessageHash;                // public
    signal input kytDepositSignature[3];                     // S,R8x,R8y
    // withdraw case
    signal input kytWithdrawSignedMessagePackageType;
    signal input kytWithdrawSignedMessageTimestamp;
    signal input kytWithdrawSignedMessageSender;            // public
    signal input kytWithdrawSignedMessageReceiver;          // public
    signal input kytWithdrawSignedMessageToken;
    signal input kytWithdrawSignedMessageSessionId;
    signal input kytWithdrawSignedMessageRuleId;
    signal input kytWithdrawSignedMessageAmount;
    signal input kytWithdrawSignedMessageChargedAmountZkp;
    signal input kytWithdrawSignedMessageSigner;
    signal input kytWithdrawSignedMessageHash;                // public
    signal input kytWithdrawSignature[3];                     // S,R8x,R8y
    // internal case
    signal input kytSignedMessagePackageType;
    signal input kytSignedMessageTimestamp;
    signal input kytSignedMessageSessionId;
    signal input kytSignedMessageChargedAmountZkp;
    signal input kytSignedMessageSigner;
    signal input kytSignedMessageDataEscrowHash;      // of data-escrow encrypted points
    signal input kytSignedMessageHash;                // public - Hash( 6-signed-message-params )
    signal input kytSignature[3];                     // S,R8x,R8y

    // data escrow
    signal input dataEscrowPubKey[2];
    signal input dataEscrowPubKeyExpiryTime;
    signal input dataEscrowEphemeralRandom;
    signal input dataEscrowEphemeralPubKeyAx; // public
    signal input dataEscrowEphemeralPubKeyAy;
    signal input dataEscrowPathElements[TrustProvidersMerkleTreeDepth];
    signal input dataEscrowPathIndices[TrustProvidersMerkleTreeDepth];

    signal input dataEscrowEncryptedMessageAx[dataEscrowEncryptedPoints]; // public
    signal input dataEscrowEncryptedMessageAy[dataEscrowEncryptedPoints];

    // dao data escrow
    signal input daoDataEscrowPubKey[2];
    signal input daoDataEscrowEphemeralRandom;
    signal input daoDataEscrowEphemeralPubKeyAx;
    signal input daoDataEscrowEphemeralPubKeyAy;

    signal input daoDataEscrowEncryptedMessageAx[daoDataEscrowEncryptedPoints]; // public
    signal input daoDataEscrowEncryptedMessageAy[daoDataEscrowEncryptedPoints];

    // output 'zAsset UTXOs'
    // to switch-off:
    //      1) utxoOutAmount = 0
    // switch-off control is used for
    //      1) withdraw only tx
    //      2) zAccount::zkpAmount & withdraw
    //      3) deposit & zAccount::zkpAmount & withdraw
    //      4) deposit & withdraw
    signal input utxoOutCreateTime;                // public
    signal input utxoOutAmount[nUtxoOut];          // in zAsset units
    signal input utxoOutOriginNetworkId[nUtxoOut];
    signal input utxoOutTargetNetworkId[nUtxoOut];
    signal input utxoOutTargetZoneId[nUtxoOut];
    signal input utxoOutTargetZoneIdOffset[nUtxoOut];
    signal input utxoOutSpendPubKeyRandom[nUtxoOut];
    signal input utxoOutRootSpendPubKey[nUtxoOut][2];
    signal input utxoOutCommitment[nUtxoOut]; // public

    // output 'zAccount UTXO'
    signal input zAccountUtxoOutZkpAmount;
    signal input zAccountUtxoOutSpendKeyRandom;
    signal input zAccountUtxoOutCommitment; // public

    // output 'protocol + relayer fee in ZKP'
    signal input chargedAmountZkp; // public

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

    // static tree merkle root
    // Poseidon of:
    // 1) zAssetMerkleRoot
    // 2) zAccountBlackListMerkleRoot
    // 3) zNetworkTreeMerkleRoot
    // 4) zZoneMerkleRoot
    // 5) trustProvidersMerkleRoot
    signal input staticTreeMerkleRoot; // public

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

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [0] - Extra inputs hash anchoring
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    extraInputsHash === 1 * extraInputsHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1] - Check zAsset
    component zAssetChecker = ZAssetChecker();
    zAssetChecker.token <== token;
    zAssetChecker.tokenId <== tokenId;
    zAssetChecker.zAssetId <== zAssetId;
    zAssetChecker.zAssetToken <== zAssetToken;
    zAssetChecker.zAssetTokenId <== zAssetTokenId;
    zAssetChecker.zAssetOffset <== zAssetOffset;
    zAssetChecker.depositAmount <== depositAmount;
    zAssetChecker.withdrawAmount <== withdrawAmount;
    zAssetChecker.utxoZAssetId <== utxoZAsset;

    // [1.1] - Check zAsset-ZKP - verify it is zkp-token
    zAssetIdZkp === 0;

    // [2] - Check the overall balance of all inputs & outputs amounts
    var totalUtxoInAmount = 0; // in zAsset units
    for (var i = 0 ; i < nUtxoIn; i++){
        // accumulate total
        totalUtxoInAmount += utxoInAmount[i];
    }

    var totalUtxoOutAmount = 0; // in zAsset units
    for (var i = 0; i < nUtxoOut; i++){
        // accumulate total
        totalUtxoOutAmount += utxoOutAmount[i];
    }

    // verify deposit & withdraw change
    component totalBalanceChecker = BalanceChecker();
    totalBalanceChecker.isZkpToken <== zAssetChecker.isZkpToken;
    totalBalanceChecker.depositAmount <== depositAmount;
    totalBalanceChecker.withdrawAmount <== withdrawAmount;
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.addedAmountZkp <== addedAmountZkp;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== totalUtxoInAmount;
    totalBalanceChecker.totalUtxoOutAmount <== totalUtxoOutAmount;
    totalBalanceChecker.zAssetWeight <== zAssetWeight;
    totalBalanceChecker.zAssetScale <== zAssetScale;
    totalBalanceChecker.zAssetScaleZkp <== zAssetScaleZkp;
    totalBalanceChecker.kytDepositChargedAmountZkp <== kytDepositSignedMessageChargedAmountZkp;
    totalBalanceChecker.kytWithdrawChargedAmountZkp <== kytWithdrawSignedMessageChargedAmountZkp;
    totalBalanceChecker.kytInternalChargedAmountZkp <== kytSignedMessageChargedAmountZkp;

    // [3] - Verify zAsset's membership and decode its weight
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

    // verify zAsset::network is equal to the current networkId
    zAssetNetwork === zNetworkId;

    // [3.1] - Verify ZKP zAsset's membership and decode its weight
    component zAssetNoteInclusionProverZkp = ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth);
    zAssetNoteInclusionProverZkp.zAsset <== zAssetIdZkp;
    zAssetNoteInclusionProverZkp.token <== zAssetTokenZkp;
    zAssetNoteInclusionProverZkp.tokenId <== zAssetTokenIdZkp;
    zAssetNoteInclusionProverZkp.network <== zAssetNetworkZkp;
    zAssetNoteInclusionProverZkp.offset <== zAssetOffsetZkp;
    zAssetNoteInclusionProverZkp.weight <== zAssetWeightZkp;
    zAssetNoteInclusionProverZkp.scale <== zAssetScaleZkp;
    zAssetNoteInclusionProverZkp.merkleRoot <== zAssetMerkleRoot;

    for (var i = 0; i < ZAssetMerkleTreeDepth; i++) {
        zAssetNoteInclusionProverZkp.pathIndices[i] <== zAssetPathIndicesZkp[i];
        zAssetNoteInclusionProverZkp.pathElements[i] <== zAssetPathElementsZkp[i];
    }

    // verify zAsset::network is equal to the current networkId
    zAssetNetworkZkp === zNetworkId;

    // [4] - Pass values for computing rewards
    component rewards = RewardsExtended(nUtxoIn);
    rewards.depositAmount <== totalBalanceChecker.depositScaledAmount;
    rewards.forTxReward <== forTxReward;
    rewards.forUtxoReward <== forUtxoReward;
    rewards.forDepositReward <== forDepositReward;
    rewards.spendTime <== spendTime;
    rewards.assetWeight <== zAssetWeight;
    // compute rewards
    for (var i = 0 ; i < nUtxoIn; i++){
        // pass value for computing rewards
        rewards.utxoInCreateTime[i] <== utxoInCreateTime[i];
        rewards.utxoInAmount[i] <== utxoInAmount[i];
    }

    // [5] - Verify input notes, membership, compute total amount of input 'zAsset UTXOs'
    component utxoInNullifierHasher[nUtxoIn];
    component utxoInNullifierProver[nUtxoIn];
    component utxoInSpendPubKey[nUtxoIn];
    component utxoInSpendPubKeyDeriver[nUtxoIn];
    component utxoInNoteHashers[nUtxoIn];
    component utxoInInclusionProver[nUtxoIn];
    component utxoInOriginZoneIdInclusionProver[nUtxoIn];
    component utxoInOriginNetworkIdInclusionProver[nUtxoIn];
    component utxoInTargetNetworkIdInclusionProver[nUtxoIn];
    component utxoInZNetworkOriginNetworkIdInclusionProver[nUtxoIn];
    component utxoInZNetworkTargetNetworkIdInclusionProver[nUtxoIn];
    component utxoInIsEnabled[nUtxoIn];
    component isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[nUtxoIn];

    for (var i = 0 ; i < nUtxoIn; i++){

        // derive spending pubkey from root-spend-pubkey (anchor to zAccount)
        utxoInSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoInSpendPubKeyDeriver[i].rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
        utxoInSpendPubKeyDeriver[i].rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
        utxoInSpendPubKeyDeriver[i].random <== utxoInSpendKeyRandom[i]; // random generated by sender

        // derive spending pubkey
        utxoInSpendPubKey[i] = BabyPbk();
        utxoInSpendPubKey[i].in <== utxoInSpendPrivKey[i]; // rootPrivKey * random

        // verify equality - can be switched-off by zero value of utxoInSpendKeyRandom & utxoInSpendPrivKey
        utxoInSpendPubKey[i].Ax === utxoInSpendPubKeyDeriver[i].derivedPubKey[0];
        utxoInSpendPubKey[i].Ay === utxoInSpendPubKeyDeriver[i].derivedPubKey[1];

        // compute commitment
        utxoInNoteHashers[i] = UtxoNoteHasher(0);
        utxoInNoteHashers[i].spendPk[0] <== utxoInSpendPubKey[i].Ax;
        utxoInNoteHashers[i].spendPk[1] <== utxoInSpendPubKey[i].Ay;
        utxoInNoteHashers[i].zAsset <== utxoZAsset;
        utxoInNoteHashers[i].amount <== utxoInAmount[i];
        utxoInNoteHashers[i].originNetworkId <== utxoInOriginNetworkId[i];
        utxoInNoteHashers[i].targetNetworkId <== utxoInTargetNetworkId[i];
        utxoInNoteHashers[i].createTime <== utxoInCreateTime[i];
        utxoInNoteHashers[i].originZoneId <== utxoInOriginZoneId[i];
        utxoInNoteHashers[i].targetZoneId <== zAccountUtxoInZoneId; // ALWAYS will be ZoneId of current zAccount
        utxoInNoteHashers[i].zAccountId <== utxoInZAccountId[i]; // ALWAYS will be ZAccountId of the sender
        utxoInNoteHashers[i].dataEscrowPubKey[0] <== utxoInDataEscrowPubKey[i][0];
        utxoInNoteHashers[i].dataEscrowPubKey[1] <== utxoInDataEscrowPubKey[i][1];

        // is-zero amount check
        utxoInIsEnabled[i] = IsNotZero();
        utxoInIsEnabled[i].in <== utxoInAmount[i];

        // verify if origin zoneId is allowed in zZone
        utxoInOriginZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoInOriginZoneIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInOriginZoneIdInclusionProver[i].zoneId <== utxoInOriginZoneId[i];
        utxoInOriginZoneIdInclusionProver[i].zoneIds <== zZoneOriginZoneIDs;
        utxoInOriginZoneIdInclusionProver[i].offset <== utxoInOriginZoneIdOffset[i];

        // verify origin networkId is allowed in zZone
        utxoInOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInOriginNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInOriginNetworkIdInclusionProver[i].networkId <== utxoInOriginNetworkId[i];
        utxoInOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;

        // verify target networkId is allowed in zZone
        utxoInTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInTargetNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInTargetNetworkIdInclusionProver[i].networkId <== utxoInTargetNetworkId[i];
        utxoInTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;

        // verify origin networkId is allowed in zNetwork (if this network accepts origin-network at all)
        utxoInZNetworkOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInZNetworkOriginNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInZNetworkOriginNetworkIdInclusionProver[i].networkId <== utxoInOriginNetworkId[i];
        utxoInZNetworkOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zNetworkIDsBitMap;

        // verify target networkId is equal to zNetworkId
        utxoInZNetworkTargetNetworkIdInclusionProver[i] = ForceEqualIfEnabled();
        utxoInZNetworkTargetNetworkIdInclusionProver[i].in[0] <== zNetworkId;
        utxoInZNetworkTargetNetworkIdInclusionProver[i].in[1] <== utxoInTargetNetworkId[i];
        utxoInZNetworkTargetNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify nullifier
        utxoInNullifierHasher[i] = NullifierHasherExtended();
        utxoInNullifierHasher[i].privKey <== zAccountUtxoInNullifierPrivKey;
        utxoInNullifierHasher[i].pubKey[0] <== utxoInDataEscrowPubKey[i][0];
        utxoInNullifierHasher[i].pubKey[1] <== utxoInDataEscrowPubKey[i][1];
        utxoInNullifierHasher[i].leaf <== utxoInNoteHashers[i].out;

        utxoInNullifierProver[i] = ForceEqualIfEnabled();
        utxoInNullifierProver[i].in[0] <== utxoInNullifier[i];
        utxoInNullifierProver[i].in[1] <== utxoInNullifierHasher[i].out;
        // As 'utxoInNullifier' is a public signal it is used for nullifier check.
        utxoInNullifierProver[i].enabled <== utxoInNullifier[i];

        // verify Merkle proofs for input notes
        utxoInInclusionProver[i] = UtxoNoteInclusionProverBinarySelectable(UtxoLeftMerkleTreeDepth,UtxoMiddleExtraLevels,UtxoRightExtraLevels);
        // leaf in MerkleTree
        utxoInInclusionProver[i].note <== utxoInNoteHashers[i].out;
        // tree selector
        utxoInInclusionProver[i].treeSelector[0] <== utxoInMerkleTreeSelector[i][0];
        utxoInInclusionProver[i].treeSelector[1] <== utxoInMerkleTreeSelector[i][1];
        // path & index
        for(var j = 0; j < UtxoMerkleTreeDepth; j++) {
            utxoInInclusionProver[i].pathElements[j] <== utxoInPathElements[i][j];
            utxoInInclusionProver[i].pathIndices[j] <== utxoInPathIndices[i][j];
        }
        // roots
        utxoInInclusionProver[i].root[0] <== taxiMerkleRoot;
        utxoInInclusionProver[i].root[1] <== busMerkleRoot;
        utxoInInclusionProver[i].root[2] <== ferryMerkleRoot;

        // switch-on membership if amount != 0, otherwise switch-off
        utxoInInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify zone max internal limits, no need to RC amount since its checked via utxo-out
        assert(0 <= utxoInAmount[i] < 2**64);
        // utxoInAmount[i] * zAssetWeight[transactedToken] - no need to RC since `zAssetWeight` anchored via MT & `amount`
        assert(zZoneInternalMaxAmount >= (utxoInAmount[i] * zAssetWeight));
        isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[i] = ForceLessEqThan(252);
        isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[i].in[0] <== utxoInAmount[i] * zAssetWeight;
        isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[i].in[1] <== zZoneInternalMaxAmount;
    }

    // [6] - Verify output notes and compute total amount of output 'zAsset UTXOs'
    component utxoOutNoteHasher[nUtxoOut];
    component utxoOutCommitmentProver[nUtxoIn];
    component utxoOutSpendPubKeyDeriver[nUtxoOut];
    component utxoOutOriginNetworkIdInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdInclusionProver[nUtxoOut];
    component utxoOutOriginNetworkIdZNetworkInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdZNetworkInclusionProver[nUtxoOut];
    component utxoOutZoneIdInclusionProver[nUtxoOut];
    component utxoOutIsEnabled[nUtxoOut];
    component isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[nUtxoOut];
    component rc_utxoOutAmount[nUtxoOut];

    for (var i = 0; i < nUtxoOut; i++){
        // derive spending pubkey from root-spend-pubkey (anchor to zAccount)
        utxoOutSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoOutSpendPubKeyDeriver[i].rootPubKey[0] <== utxoOutRootSpendPubKey[i][0];
        utxoOutSpendPubKeyDeriver[i].rootPubKey[1] <== utxoOutRootSpendPubKey[i][1];
        utxoOutSpendPubKeyDeriver[i].random <== utxoOutSpendPubKeyRandom[i]; // random generated by sender

        // verify commitment
        utxoOutNoteHasher[i] = UtxoNoteHasher(0);
        utxoOutNoteHasher[i].spendPk[0] <== utxoOutSpendPubKeyDeriver[i].derivedPubKey[0];
        utxoOutNoteHasher[i].spendPk[1] <== utxoOutSpendPubKeyDeriver[i].derivedPubKey[1];
        utxoOutNoteHasher[i].zAsset <== utxoZAsset;
        utxoOutNoteHasher[i].amount <== utxoOutAmount[i];
        utxoOutNoteHasher[i].originNetworkId <== utxoOutOriginNetworkId[i];
        utxoOutNoteHasher[i].targetNetworkId <== utxoOutTargetNetworkId[i];
        utxoOutNoteHasher[i].createTime <== utxoOutCreateTime;
        utxoOutNoteHasher[i].originZoneId <== zAccountUtxoInZoneId; // ALWAYS will be ZoneId of current zAccount
        utxoOutNoteHasher[i].targetZoneId <== utxoOutTargetZoneId[i];
        utxoOutNoteHasher[i].zAccountId <== zAccountUtxoInId; // ALWAYS will be ZAccountId of current zAccount
        utxoOutNoteHasher[i].dataEscrowPubKey[0] <== dataEscrowPubKey[0];
        utxoOutNoteHasher[i].dataEscrowPubKey[1] <== dataEscrowPubKey[1];

        utxoOutCommitmentProver[i] = ForceEqualIfEnabled();
        utxoOutCommitmentProver[i].enabled <== utxoOutCommitment[i];
        utxoOutCommitmentProver[i].in[0] <== utxoOutCommitment[i];
        utxoOutCommitmentProver[i].in[1] <== utxoOutNoteHasher[i].out;

        // verify if target zoneId is allowed in zZone (originZoneId verified via zAccount)
        utxoOutZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoOutZoneIdInclusionProver[i].enabled <== utxoOutCommitment[i];
        utxoOutZoneIdInclusionProver[i].zoneId <== utxoOutTargetZoneId[i];
        utxoOutZoneIdInclusionProver[i].zoneIds <== zZoneTargetZoneIDs;
        utxoOutZoneIdInclusionProver[i].offset <== utxoOutTargetZoneIdOffset[i];

        // verify origin networkId is allowed in zZone
        utxoOutOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutOriginNetworkIdInclusionProver[i].enabled <== utxoOutCommitment[i];
        utxoOutOriginNetworkIdInclusionProver[i].networkId <== utxoOutOriginNetworkId[i];
        utxoOutOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;

        // verify target networkId is allowed in zZone
        utxoOutTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdInclusionProver[i].enabled <== utxoOutCommitment[i];
        utxoOutTargetNetworkIdInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;

        // verify origin networkId is allowed (same as zNetworkId) in zNetwork
        utxoOutOriginNetworkIdZNetworkInclusionProver[i] = ForceEqualIfEnabled();
        utxoOutOriginNetworkIdZNetworkInclusionProver[i].enabled <== utxoOutCommitment[i];
        utxoOutOriginNetworkIdZNetworkInclusionProver[i].in[0] <== zNetworkId;
        utxoOutOriginNetworkIdZNetworkInclusionProver[i].in[1] <== utxoOutOriginNetworkId[i];

        // verify target networkId is allowed in zNetwork
        utxoOutTargetNetworkIdZNetworkInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdZNetworkInclusionProver[i].enabled <== utxoOutCommitment[i];
        utxoOutTargetNetworkIdZNetworkInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdZNetworkInclusionProver[i].networkIdsBitMap <== zNetworkIDsBitMap;

        // verify zone max internal limits
        assert(zZoneInternalMaxAmount >= (utxoOutAmount[i] * zAssetWeight));
        isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i] = ForceLessEqThan(252);
        isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i].in[0] <== utxoOutAmount[i] * zAssetWeight;
        isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i].in[1] <== zZoneInternalMaxAmount;

        // ensure output amounts ranges
        assert(0 <= utxoOutAmount[i] < 2**64);
        rc_utxoOutAmount[i] = LessThanBits(64);
        rc_utxoOutAmount[i].in <== utxoOutAmount[i];
    }

    // [7] - Verify zZone max amount per time period
    assert(utxoOutCreateTime >= zAccountUtxoInCreateTime);
    component isLessThanEq_zAccountUtxoInCreateTime_utxoOutCreateTime = ForceLessEqThan(252);
    isLessThanEq_zAccountUtxoInCreateTime_utxoOutCreateTime.in[0] <== zAccountUtxoInCreateTime;
    isLessThanEq_zAccountUtxoInCreateTime_utxoOutCreateTime.in[1] <== utxoOutCreateTime;

    signal deltaTime <== utxoOutCreateTime - zAccountUtxoInCreateTime;

    component isDeltaTimeLessEqThen = LessEqThan(252); // 1 if deltaTime <= zZoneTimePeriodPerMaximumAmount
    isDeltaTimeLessEqThen.in[0] <== deltaTime;
    isDeltaTimeLessEqThen.in[1] <== zZoneTimePeriodPerMaximumAmount;

    signal zAccountUtxoOutTotalAmountPerTimePeriod <== isDeltaTimeLessEqThen.out * (totalBalanceChecker.totalWeighted + zAccountUtxoInTotalAmountPerTimePeriod);

    // verify
    assert(zAccountUtxoOutTotalAmountPerTimePeriod <= zZoneMaximumAmountPerTimePeriod);
    component isLessThanEq_zAccountUtxoOutTotalAmountPerTimePeriod_zZoneMaximumAmountPerTimePeriod = ForceLessEqThan(252);
    isLessThanEq_zAccountUtxoOutTotalAmountPerTimePeriod_zZoneMaximumAmountPerTimePeriod.in[0] <== zAccountUtxoOutTotalAmountPerTimePeriod;
    isLessThanEq_zAccountUtxoOutTotalAmountPerTimePeriod_zZoneMaximumAmountPerTimePeriod.in[1] <== zZoneMaximumAmountPerTimePeriod;

    // [8] - Verify input 'zAccount UTXO input'
    component zAccountUtxoInSpendPubKey = BabyPbk();
    zAccountUtxoInSpendPubKey.in <== zAccountUtxoInSpendPrivKey;

    component zAccountUtxoInHasher = ZAccountNoteHasher();
    zAccountUtxoInHasher.spendPubKey[0] <== zAccountUtxoInSpendPubKey.Ax;
    zAccountUtxoInHasher.spendPubKey[1] <== zAccountUtxoInSpendPubKey.Ay;
    zAccountUtxoInHasher.rootSpendPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoInHasher.rootSpendPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoInHasher.readPubKey[0] <== zAccountUtxoInReadPubKey[0];
    zAccountUtxoInHasher.readPubKey[1] <== zAccountUtxoInReadPubKey[1];
    zAccountUtxoInHasher.nullifierPubKey[0] <== zAccountUtxoInNullifierPubKey[0];
    zAccountUtxoInHasher.nullifierPubKey[1] <== zAccountUtxoInNullifierPubKey[1];
    zAccountUtxoInHasher.masterEOA <== zAccountUtxoInMasterEOA;
    zAccountUtxoInHasher.id <== zAccountUtxoInId;
    zAccountUtxoInHasher.amountZkp <== zAccountUtxoInZkpAmount;
    zAccountUtxoInHasher.amountPrp <== zAccountUtxoInPrpAmount;
    zAccountUtxoInHasher.zoneId <== zAccountUtxoInZoneId;
    zAccountUtxoInHasher.expiryTime <== zAccountUtxoInExpiryTime;
    zAccountUtxoInHasher.nonce <== zAccountUtxoInNonce;
    zAccountUtxoInHasher.totalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zAccountUtxoInHasher.createTime <== zAccountUtxoInCreateTime;
    zAccountUtxoInHasher.networkId <== zAccountUtxoInNetworkId;

    // verify zNetworkId is equal to zAccountUtxoInNetworkId (anchoring)
    zAccountUtxoInNetworkId === zNetworkId;

    // [9] - Verify zAccountUtxoIn nullifier
    // verify nullifier key
    component zAccountNullifierPubKeyChecker = BabyPbk();
    zAccountNullifierPubKeyChecker.in <== zAccountUtxoInNullifierPrivKey;
    zAccountNullifierPubKeyChecker.Ax === zAccountUtxoInNullifierPubKey[0];
    zAccountNullifierPubKeyChecker.Ay === zAccountUtxoInNullifierPubKey[1];

    component zAccountUtxoInNullifierHasher = ZAccountNullifierHasher();
    zAccountUtxoInNullifierHasher.privKey <== zAccountUtxoInNullifierPrivKey;
    zAccountUtxoInNullifierHasher.commitment <== zAccountUtxoInHasher.out;

    component zAccountUtxoInNullifierHasherProver = ForceEqualIfEnabled();
    zAccountUtxoInNullifierHasherProver.in[0] <== zAccountUtxoInNullifier;
    zAccountUtxoInNullifierHasherProver.in[1] <== zAccountUtxoInNullifierHasher.out;
    zAccountUtxoInNullifierHasherProver.enabled <== zAccountUtxoInSpendPrivKey;

    // verify reading key
    component zAccountReadPubKeyChecker = BabyPbk();
    zAccountReadPubKeyChecker.in <== zAccountUtxoInReadPrivKey;
    zAccountReadPubKeyChecker.Ax === zAccountUtxoInReadPubKey[0];
    zAccountReadPubKeyChecker.Ay === zAccountUtxoInReadPubKey[1];

    // [10] - Verify zAccountUtxoIn membership
    component zAccountUtxoInMerkleVerifier = MerkleTreeInclusionProofDoubleLeavesSelectable(UtxoLeftMerkleTreeDepth,UtxoMiddleExtraLevels,UtxoRightExtraLevels);
    zAccountUtxoInMerkleVerifier.leaf <== zAccountUtxoInHasher.out;
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
    // zAccountUtxoInMerkleVerifier.root === zAccountUtxoInMerkleRoot;

    // [11] - Verify zAccountUtxoOut spend-pub-key is indeed derivation of zAccountRootSpendKey
    component zAccountUtxoOutPubKeyDeriver = PubKeyDeriver();
    zAccountUtxoOutPubKeyDeriver.rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoOutPubKeyDeriver.rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoOutPubKeyDeriver.random <== zAccountUtxoOutSpendKeyRandom;

    // [12] - Verify zAccountUtxoOut commitment
    component zAccountUtxoOutHasher = ZAccountNoteHasher();
    zAccountUtxoOutHasher.spendPubKey[0] <== zAccountUtxoOutPubKeyDeriver.derivedPubKey[0];
    zAccountUtxoOutHasher.spendPubKey[1] <== zAccountUtxoOutPubKeyDeriver.derivedPubKey[1];
    zAccountUtxoOutHasher.rootSpendPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoOutHasher.rootSpendPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoOutHasher.readPubKey[0] <== zAccountUtxoInReadPubKey[0];
    zAccountUtxoOutHasher.readPubKey[1] <== zAccountUtxoInReadPubKey[1];
    zAccountUtxoOutHasher.nullifierPubKey[0] <== zAccountUtxoInNullifierPubKey[0];
    zAccountUtxoOutHasher.nullifierPubKey[1] <== zAccountUtxoInNullifierPubKey[1];
    zAccountUtxoOutHasher.masterEOA <== zAccountUtxoInMasterEOA;
    zAccountUtxoOutHasher.id <== zAccountUtxoInId;
    zAccountUtxoOutHasher.amountZkp <== zAccountUtxoOutZkpAmount;
    zAccountUtxoOutHasher.amountPrp <== zAccountUtxoInPrpAmount + rewards.amountPrp;
    zAccountUtxoOutHasher.zoneId <== zAccountUtxoInZoneId;
    zAccountUtxoOutHasher.expiryTime <== zAccountUtxoInExpiryTime;
    zAccountUtxoOutHasher.nonce <== zAccountUtxoInNonce + 1;
    zAccountUtxoOutHasher.totalAmountPerTimePeriod <== zAccountUtxoOutTotalAmountPerTimePeriod;
    zAccountUtxoOutHasher.createTime <== utxoOutCreateTime;
    zAccountUtxoOutHasher.networkId <== zAccountUtxoInNetworkId;

    component zAccountUtxoOutHasherProver = ForceEqualIfEnabled();
    zAccountUtxoOutHasherProver.in[0] <== zAccountUtxoOutCommitment;
    zAccountUtxoOutHasherProver.in[1] <== zAccountUtxoOutHasher.out;
    zAccountUtxoOutHasherProver.enabled <== zAccountUtxoOutCommitment;

    // [13] - Verify zAccoutId exclusion proof
    component zAccountBlackListInlcusionProver = ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.zAccountId <== zAccountUtxoInId;
    zAccountBlackListInlcusionProver.leaf <== zAccountBlackListLeaf;
    zAccountBlackListInlcusionProver.merkleRoot <== zAccountBlackListMerkleRoot;
    for (var j = 0; j < ZZoneMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== zAccountBlackListPathElements[j];
    }

    // [14] - Verify KYT signature
    component isZeroDeposit = IsZero();
    isZeroDeposit.in <== depositAmount;

    component isZeroWithdraw = IsZero();
    isZeroWithdraw.in <== withdrawAmount;

    component isZeroInternal = IsZero();
    isZeroInternal.in <== zZoneSealing;

    component isKytCheckEnabled_deposit_withdraw = OR(); // result = a+b - a*b
    isKytCheckEnabled_deposit_withdraw.a <== 1 - isZeroDeposit.out;
    isKytCheckEnabled_deposit_withdraw.b <== 1 - isZeroWithdraw.out;

    component isKytCheckEnabled = OR(); // result = a+b - a*b
    isKytCheckEnabled.a <== 1 - isZeroInternal.out;
    isKytCheckEnabled.b <== isKytCheckEnabled_deposit_withdraw.out;

    signal isKytDepositCheckEnabled <== 1 - isZeroDeposit.out;

    component kytDepositSignedMessageHashInternal = Poseidon(10);

    kytDepositSignedMessageHashInternal.inputs[0] <== kytDepositSignedMessagePackageType;
    kytDepositSignedMessageHashInternal.inputs[1] <== kytDepositSignedMessageTimestamp;
    kytDepositSignedMessageHashInternal.inputs[2] <== kytDepositSignedMessageSender;
    kytDepositSignedMessageHashInternal.inputs[3] <== kytDepositSignedMessageReceiver;
    kytDepositSignedMessageHashInternal.inputs[4] <== kytDepositSignedMessageToken;
    kytDepositSignedMessageHashInternal.inputs[5] <== kytDepositSignedMessageSessionId;
    kytDepositSignedMessageHashInternal.inputs[6] <== kytDepositSignedMessageRuleId;
    kytDepositSignedMessageHashInternal.inputs[7] <== kytDepositSignedMessageAmount;
    kytDepositSignedMessageHashInternal.inputs[8] <== kytDepositSignedMessageSigner;
    kytDepositSignedMessageHashInternal.inputs[9] <== kytDepositSignedMessageChargedAmountZkp;

    component kytDepositSignatureVerifier = EdDSAPoseidonVerifier();
    kytDepositSignatureVerifier.enabled <== isKytDepositCheckEnabled;
    kytDepositSignatureVerifier.Ax <== kytEdDsaPubKey[0];
    kytDepositSignatureVerifier.Ay <== kytEdDsaPubKey[1];
    kytDepositSignatureVerifier.S <== kytDepositSignature[0];
    kytDepositSignatureVerifier.R8x <== kytDepositSignature[1];
    kytDepositSignatureVerifier.R8y <== kytDepositSignature[2];

    kytDepositSignatureVerifier.M <== kytDepositSignedMessageHashInternal.out;

    // deposit Master EOA check
    component kytDepositMasterEOAIsEqual = ForceEqualIfEnabled();
    kytDepositMasterEOAIsEqual.enabled <== isKytDepositCheckEnabled;
    kytDepositMasterEOAIsEqual.in[0] <== kytDepositSignedMessageSigner;
    kytDepositMasterEOAIsEqual.in[1] <== zAccountUtxoInMasterEOA;

    // deposit kyt-hash
    component kytDepositSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kytDepositSignedMessageHashIsEqual.enabled <== isKytDepositCheckEnabled;
    kytDepositSignedMessageHashIsEqual.in[0] <== kytDepositSignedMessageHash;
    kytDepositSignedMessageHashIsEqual.in[1] <== kytDepositSignedMessageHashInternal.out;

    // deposit token
    component kytDepositSignedMessageTokenIsEqual = ForceEqualIfEnabled();
    kytDepositSignedMessageTokenIsEqual.enabled <== isKytDepositCheckEnabled;
    kytDepositSignedMessageTokenIsEqual.in[0] <== token;
    kytDepositSignedMessageTokenIsEqual.in[1] <== kytDepositSignedMessageToken;

    // deposit amount
    component kytDepositSignedMessageAmountIsEqual = ForceEqualIfEnabled();
    kytDepositSignedMessageAmountIsEqual.enabled <== isKytDepositCheckEnabled;
    kytDepositSignedMessageAmountIsEqual.in[0] <== depositAmount;
    kytDepositSignedMessageAmountIsEqual.in[1] <== kytDepositSignedMessageAmount;

    // deposit package type
    kytDepositSignedMessagePackageType === 2;

    signal isKytWithdrawCheckEnabled <== 1 - isZeroWithdraw.out;

    component kytWithdrawSignedMessageHashInternal = Poseidon(10);

    kytWithdrawSignedMessageHashInternal.inputs[0] <== kytWithdrawSignedMessagePackageType;
    kytWithdrawSignedMessageHashInternal.inputs[1] <== kytWithdrawSignedMessageTimestamp;
    kytWithdrawSignedMessageHashInternal.inputs[2] <== kytWithdrawSignedMessageSender;
    kytWithdrawSignedMessageHashInternal.inputs[3] <== kytWithdrawSignedMessageReceiver;
    kytWithdrawSignedMessageHashInternal.inputs[4] <== kytWithdrawSignedMessageToken;
    kytWithdrawSignedMessageHashInternal.inputs[5] <== kytWithdrawSignedMessageSessionId;
    kytWithdrawSignedMessageHashInternal.inputs[6] <== kytWithdrawSignedMessageRuleId;
    kytWithdrawSignedMessageHashInternal.inputs[7] <== kytWithdrawSignedMessageAmount;
    kytWithdrawSignedMessageHashInternal.inputs[8] <== kytWithdrawSignedMessageSigner;
    kytWithdrawSignedMessageHashInternal.inputs[9] <== kytWithdrawSignedMessageChargedAmountZkp;

    component kytWithdrawSignatureVerifier = EdDSAPoseidonVerifier();
    kytWithdrawSignatureVerifier.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawSignatureVerifier.Ax <== kytEdDsaPubKey[0];
    kytWithdrawSignatureVerifier.Ay <== kytEdDsaPubKey[1];
    kytWithdrawSignatureVerifier.S <== kytWithdrawSignature[0];
    kytWithdrawSignatureVerifier.R8x <== kytWithdrawSignature[1];
    kytWithdrawSignatureVerifier.R8y <== kytWithdrawSignature[2];

    kytWithdrawSignatureVerifier.M <== kytWithdrawSignedMessageHashInternal.out;

    // withdraw Master EOA check
    component kytWithdrawMasterEOAIsEqual = ForceEqualIfEnabled();
    kytWithdrawMasterEOAIsEqual.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawMasterEOAIsEqual.in[0] <== kytWithdrawSignedMessageSigner;
    kytWithdrawMasterEOAIsEqual.in[1] <== zAccountUtxoInMasterEOA;

    // withdraw kyt hash
    component kytWithdrawSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kytWithdrawSignedMessageHashIsEqual.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawSignedMessageHashIsEqual.in[0] <== kytWithdrawSignedMessageHash;
    kytWithdrawSignedMessageHashIsEqual.in[1] <== kytWithdrawSignedMessageHashInternal.out;

    // withdraw token
    component kytWithdrawSignedMessageTokenIsEqual = ForceEqualIfEnabled();
    kytWithdrawSignedMessageTokenIsEqual.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawSignedMessageTokenIsEqual.in[0] <== token;
    kytWithdrawSignedMessageTokenIsEqual.in[1] <== kytWithdrawSignedMessageToken;

    // withdraw amount
    component kytWithdrawSignedMessageAmountIsEqual = ForceEqualIfEnabled();
    kytWithdrawSignedMessageAmountIsEqual.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawSignedMessageAmountIsEqual.in[0] <== withdrawAmount;
    kytWithdrawSignedMessageAmountIsEqual.in[1] <== kytWithdrawSignedMessageAmount;

    // withdraw package type
    kytWithdrawSignedMessagePackageType === 2;

    // [15] - Verify kytEdDSA public key membership
    component kytKycNoteInclusionProver = TrustProvidersNoteInclusionProver(TrustProvidersMerkleTreeDepth);
    kytKycNoteInclusionProver.enabled <== isKytCheckEnabled.out;
    kytKycNoteInclusionProver.root <== trustProvidersMerkleRoot;
    kytKycNoteInclusionProver.key[0] <== kytEdDsaPubKey[0];
    kytKycNoteInclusionProver.key[1] <== kytEdDsaPubKey[1];
    kytKycNoteInclusionProver.expiryTime <== kytEdDsaPubKeyExpiryTime;
    for (var j=0; j< TrustProvidersMerkleTreeDepth; j++) {
        kytKycNoteInclusionProver.pathIndices[j] <== kytPathIndices[j];
        kytKycNoteInclusionProver.pathElements[j] <== kytPathElements[j];
    }

    // [16] - Verify kyt leaf-id & rule allowed in zZone - required if deposit or withdraw != 0
    component b2nLeafId = Bits2Num(TrustProvidersMerkleTreeDepth);
    for (var j = 0; j < TrustProvidersMerkleTreeDepth; j++) {
        b2nLeafId.in[j] <== kytPathIndices[j];
    }
    // deposit part
    component kytDepositLeafIdAndRuleInclusionProver = TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver();
    kytDepositLeafIdAndRuleInclusionProver.enabled <== isKytDepositCheckEnabled;
    kytDepositLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kytDepositLeafIdAndRuleInclusionProver.rule <== kytDepositSignedMessageRuleId;
    kytDepositLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    kytDepositLeafIdAndRuleInclusionProver.offset <== kytMerkleTreeLeafIDsAndRulesOffset;
    // withdraw part
    component kytWithdrawLeafIdAndRuleInclusionProver = TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver();
    kytWithdrawLeafIdAndRuleInclusionProver.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kytWithdrawLeafIdAndRuleInclusionProver.rule <== kytWithdrawSignedMessageRuleId;
    kytWithdrawLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    kytWithdrawLeafIdAndRuleInclusionProver.offset <== kytMerkleTreeLeafIDsAndRulesOffset;

    // [17] - Verify DataEscrow public key membership
    component isDataEscrowInclusionProverEnabled = IsNotZero();
    isDataEscrowInclusionProverEnabled.in <== trustProvidersMerkleRoot;

    component dataEscrowInclusionProver = TrustProvidersNoteInclusionProver(TrustProvidersMerkleTreeDepth);
    dataEscrowInclusionProver.enabled <== isDataEscrowInclusionProverEnabled.out;
    dataEscrowInclusionProver.root <== trustProvidersMerkleRoot;
    dataEscrowInclusionProver.key[0] <== dataEscrowPubKey[0];
    dataEscrowInclusionProver.key[1] <== dataEscrowPubKey[1];
    dataEscrowInclusionProver.expiryTime <== dataEscrowPubKeyExpiryTime;

    for (var j = 0; j < TrustProvidersMerkleTreeDepth; j++) {
        dataEscrowInclusionProver.pathIndices[j] <== dataEscrowPathIndices[j];
        dataEscrowInclusionProver.pathElements[j] <== dataEscrowPathElements[j];
    }

    // [18] - Data Escrow encryption
    // ------------- scalars-size --------------
    // 1) 1 x 64 (zAsset)
    // 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
    // 3) nUtxoIn x 64 amount
    // 4) nUtxoOut x 64 amount
    // 5) MAX(nUtxoIn,nUtxoOut) x ( , utxoInPathIndices[..] << 32 bit | utxo-in-origin-zones-ids << 16 | utxo-out-target-zone-ids << 0 )
    // ------------- ec-points-size -------------
    // 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)
    component dataEscrow = DataEscrowElGamalEncryption(dataEscrowScalarSize,dataEscrowPointSize);

    dataEscrow.ephemeralRandom <== dataEscrowEphemeralRandom;
    dataEscrow.pubKey[0] <== dataEscrowPubKey[0];
    dataEscrow.pubKey[1] <== dataEscrowPubKey[1];

    // --------------- scalars -----------------
    component dataEscrowScalarsSerializer = DataEscrowSerializer(nUtxoIn,nUtxoOut,UtxoMerkleTreeDepth);
    dataEscrowScalarsSerializer.zAsset <== utxoZAsset;
    dataEscrowScalarsSerializer.zAccountId <== zAccountUtxoInId;
    dataEscrowScalarsSerializer.zAccountZoneId <== zAccountUtxoInZoneId;

    for (var j = 0; j < nUtxoIn; j++) {
        for(var i = 0; i < 2; i++) {
            dataEscrowScalarsSerializer.utxoInMerkleTreeSelector[j][i] <== utxoInMerkleTreeSelector[j][i];
        }
        for(var i = 0; i < UtxoMerkleTreeDepth; i++) {
            dataEscrowScalarsSerializer.utxoInPathIndices[j][i] <== utxoInPathIndices[j][i];
        }
        dataEscrowScalarsSerializer.utxoInAmount[j] <== utxoInAmount[j];
        dataEscrowScalarsSerializer.utxoInOriginZoneId[j] <== utxoInOriginZoneId[j];
    }

    for (var j = 0; j < nUtxoOut; j++) {
        dataEscrowScalarsSerializer.utxoOutAmount[j] <== utxoOutAmount[j];
        dataEscrowScalarsSerializer.utxoOutTargetZoneId[j] <== utxoOutTargetZoneId[j];
    }

    for (var j = 0; j < dataEscrowScalarSize; j++) {
        dataEscrow.scalarMessage[j] <== dataEscrowScalarsSerializer.out[j];
    }

    // ------------------ EC-Points ------------------
    // 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)
    for (var j = 0; j < nUtxoOut; j++) {
        dataEscrow.pointMessage[j][0] <== utxoOutRootSpendPubKey[j][0];
        dataEscrow.pointMessage[j][1] <== utxoOutRootSpendPubKey[j][1];
    }

    // verify EphemeralPubKey
    dataEscrowEphemeralPubKeyAx === dataEscrow.ephemeralPubKey[0];
    dataEscrowEphemeralPubKeyAy === dataEscrow.ephemeralPubKey[1];

    // verify Encryption
    for (var i = 0; i < dataEscrowEncryptedPoints; i++) {
        dataEscrowEncryptedMessageAx[i] === dataEscrow.encryptedMessage[i][0];
        dataEscrowEncryptedMessageAy[i] === dataEscrow.encryptedMessage[i][1];
    }

    // [19] - DAO Data Escrow encryption
    component daoDataEscrow = DataEscrowElGamalEncryptionPoint(daoDataEscrowEncryptedPoints);

    daoDataEscrow.ephemeralRandom <== daoDataEscrowEphemeralRandom;
    daoDataEscrow.pubKey[0] <== daoDataEscrowPubKey[0];
    daoDataEscrow.pubKey[1] <== daoDataEscrowPubKey[1];

    // push the only single point - the ephemeralPubKey
    daoDataEscrow.pointMessage[0][0] <== dataEscrow.ephemeralPubKey[0];
    daoDataEscrow.pointMessage[0][1] <== dataEscrow.ephemeralPubKey[1];

    // verify EphemeralPubKey
    daoDataEscrowEphemeralPubKeyAx === daoDataEscrow.ephemeralPubKey[0];
    daoDataEscrowEphemeralPubKeyAy === daoDataEscrow.ephemeralPubKey[1];

    // verify Encryption
    for (var i = 0; i < daoDataEscrowEncryptedPoints; i++) {
       daoDataEscrowEncryptedMessageAx[i] === daoDataEscrow.encryptedMessage[i][0];
       daoDataEscrowEncryptedMessageAy[i] === daoDataEscrow.encryptedMessage[i][1];
    }

    // [20] - internal KYT
    signal isKytInternalCheckEnabled <== 1 - isZeroInternal.out;

    component kytSignedMessageHashInternal = Poseidon(6);

    kytSignedMessageHashInternal.inputs[0] <== kytSignedMessagePackageType;
    kytSignedMessageHashInternal.inputs[1] <== kytSignedMessageTimestamp;
    kytSignedMessageHashInternal.inputs[2] <== kytSignedMessageSessionId;
    kytSignedMessageHashInternal.inputs[3] <== kytSignedMessageSigner;
    kytSignedMessageHashInternal.inputs[4] <== kytSignedMessageChargedAmountZkp;
    kytSignedMessageHashInternal.inputs[5] <== dataEscrow.encryptedMessageHash;

    component kytSignatureVerifier = EdDSAPoseidonVerifier();
    kytSignatureVerifier.enabled <== isKytInternalCheckEnabled;
    kytSignatureVerifier.Ax <== kytEdDsaPubKey[0];
    kytSignatureVerifier.Ay <== kytEdDsaPubKey[1];
    kytSignatureVerifier.S <== kytSignature[0];
    kytSignatureVerifier.R8x <== kytSignature[1];
    kytSignatureVerifier.R8y <== kytSignature[2];

    kytSignatureVerifier.M <== kytSignedMessageHashInternal.out;

    // internal Master EOA check
    component kytMasterEOAIsEqual = ForceEqualIfEnabled();
    kytMasterEOAIsEqual.enabled <== isKytInternalCheckEnabled;
    kytMasterEOAIsEqual.in[0] <== kytSignedMessageSigner;
    kytMasterEOAIsEqual.in[1] <== zAccountUtxoInMasterEOA;

    // internal kyt hash
    component kytSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kytSignedMessageHashIsEqual.enabled <== isKytInternalCheckEnabled;
    kytSignedMessageHashIsEqual.in[0] <== kytSignedMessageHash;
    kytSignedMessageHashIsEqual.in[1] <== kytSignedMessageHashInternal.out;

    // internal package type
    kytSignedMessagePackageType === 3;

    // [21] - Verify zZone membership
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
    zZoneNoteHasher.dataEscrowPubKey[0] <== dataEscrowPubKey[0];
    zZoneNoteHasher.dataEscrowPubKey[1] <== dataEscrowPubKey[1];
    zZoneNoteHasher.sealing <== zZoneSealing;

    component zZoneInclusionProver = ZZoneNoteInclusionProver(ZZoneMerkleTreeDepth);
    zZoneInclusionProver.zZoneCommitment <== zZoneNoteHasher.out;
    zZoneInclusionProver.root <== zZoneMerkleRoot;
    for (var j=0; j < ZZoneMerkleTreeDepth; j++) {
        zZoneInclusionProver.pathIndices[j] <== zZonePathIndices[j];
        zZoneInclusionProver.pathElements[j] <== zZonePathElements[j];
    }

    // [22] - Verify zZone max external limits
    assert(zZoneDepositMaxAmount >= totalBalanceChecker.depositWeightedScaledAmount);
    component isLessThanEq_depositWeightedScaledAmount_zZoneDepositMaxAmount = ForceLessEqThan(252);
    isLessThanEq_depositWeightedScaledAmount_zZoneDepositMaxAmount.in[0] <== totalBalanceChecker.depositWeightedScaledAmount;
    isLessThanEq_depositWeightedScaledAmount_zZoneDepositMaxAmount.in[1] <== zZoneDepositMaxAmount;

    assert(zZoneWithrawMaxAmount >= totalBalanceChecker.withdrawWeightedScaledAmount);
    component isLessThanEq_withdrawWeightedScaledAmount_zZoneWithrawMaxAmount = ForceLessEqThan(252);
    isLessThanEq_withdrawWeightedScaledAmount_zZoneWithrawMaxAmount.in[0] <== totalBalanceChecker.withdrawWeightedScaledAmount;
    isLessThanEq_withdrawWeightedScaledAmount_zZoneWithrawMaxAmount.in[1] <== zZoneWithrawMaxAmount;

    // [23] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountUtxoInId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [24] - zAccountId data escrow for zone operator
    component zZoneDataEscrow = DataEscrowElGamalEncryptionPoint(zZoneDataEscrowEncryptedPoints);

    zZoneDataEscrow.ephemeralRandom <== zZoneDataEscrowEphemeralRandom;
    zZoneDataEscrow.pubKey[0] <== zZoneEdDsaPubKey[0];
    zZoneDataEscrow.pubKey[1] <== zZoneEdDsaPubKey[1];

    // push the only single point - the ephemeralPubKey
    zZoneDataEscrow.pointMessage[0][0] <== dataEscrow.ephemeralPubKey[0];
    zZoneDataEscrow.pointMessage[0][1] <== dataEscrow.ephemeralPubKey[1];

    // verify EphemeralPubKey
    zZoneDataEscrowEphemeralPubKeyAx === zZoneDataEscrow.ephemeralPubKey[0];
    zZoneDataEscrowEphemeralPubKeyAy === zZoneDataEscrow.ephemeralPubKey[1];

    // verify Encryption
    for (var i = 0; i < zZoneDataEscrowEncryptedPoints; i++) {
        zZoneDataEscrowEncryptedMessageAx[i] === zZoneDataEscrow.encryptedMessage[i][0];
        zZoneDataEscrowEncryptedMessageAy[i] === zZoneDataEscrow.encryptedMessage[i][1];
    }

    // [25] - Verify zNetwork's membership and decode its weight
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

    // [26] - verify expiryTimes
    assert(zAccountUtxoInExpiryTime >= utxoOutCreateTime);
    component isLessThanEq_utxoOutCreateTime_zAccountUtxoInExpiryTime = ForceLessEqThan(252);
    isLessThanEq_utxoOutCreateTime_zAccountUtxoInExpiryTime.in[0] <== utxoOutCreateTime;
    isLessThanEq_utxoOutCreateTime_zAccountUtxoInExpiryTime.in[1] <== zAccountUtxoInExpiryTime;

    // assert(kytDepositSignedMessageTimestamp <= kytEdDsaPubKeyExpiryTime);
    component isLessThanEq_DepositTime_kytEdDsaPubKeyExpiryTime = LessEqThanWhenEnabled(252);
    isLessThanEq_DepositTime_kytEdDsaPubKeyExpiryTime.enabled <== isKytDepositCheckEnabled;
    isLessThanEq_DepositTime_kytEdDsaPubKeyExpiryTime.in[0] <== kytDepositSignedMessageTimestamp;
    isLessThanEq_DepositTime_kytEdDsaPubKeyExpiryTime.in[1] <== kytEdDsaPubKeyExpiryTime;

    // assert(kytWithdrawSignedMessageTimestamp <= kytEdDsaPubKeyExpiryTime);
    component isLessThanEq_WithdrawTime_kytEdDsaPubKeyExpiryTime = LessEqThanWhenEnabled(252);
    isLessThanEq_WithdrawTime_kytEdDsaPubKeyExpiryTime.enabled <== isKytWithdrawCheckEnabled;
    isLessThanEq_WithdrawTime_kytEdDsaPubKeyExpiryTime.in[0] <== kytWithdrawSignedMessageTimestamp;
    isLessThanEq_WithdrawTime_kytEdDsaPubKeyExpiryTime.in[1] <== kytEdDsaPubKeyExpiryTime;

    // assert(kytSignedMessageTimestamp <= kytEdDsaPubKeyExpiryTime);
    component isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime = LessEqThanWhenEnabled(252);
    isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime.enabled <== isKytInternalCheckEnabled;
    isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime.in[0] <== kytSignedMessageTimestamp;
    isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime.in[1] <== kytEdDsaPubKeyExpiryTime;

    assert(dataEscrowPubKeyExpiryTime >= utxoOutCreateTime);
    component isLessThanEq_utxoOutCreateTime_dataEscrowPubKeyExpiryTime = ForceLessEqThan(252);
    isLessThanEq_utxoOutCreateTime_dataEscrowPubKeyExpiryTime.in[0] <== utxoOutCreateTime;
    isLessThanEq_utxoOutCreateTime_dataEscrowPubKeyExpiryTime.in[1] <== dataEscrowPubKeyExpiryTime;

    // [26.1] - deposit
    // assert(kytDepositSignedMessageTimestamp + zZoneKytExpiryTime >= utxoOutCreateTime);
    component isLessThanEq_utxoOutCreateTime_depositTimestamp = LessEqThanWhenEnabled(252);
    isLessThanEq_utxoOutCreateTime_depositTimestamp.enabled <== isKytDepositCheckEnabled;
    isLessThanEq_utxoOutCreateTime_depositTimestamp.in[0] <== utxoOutCreateTime;
    isLessThanEq_utxoOutCreateTime_depositTimestamp.in[1] <== kytDepositSignedMessageTimestamp + zZoneKytExpiryTime;

    // [26.2] - withdraw
    // assert(kytWithdrawSignedMessageTimestamp + zZoneKytExpiryTime >= utxoOutCreateTime);
    component isLessThanEq_utxoOutCreateTime_withdrawTimestamp = LessEqThanWhenEnabled(252);
    isLessThanEq_utxoOutCreateTime_withdrawTimestamp.enabled <== isKytWithdrawCheckEnabled;
    isLessThanEq_utxoOutCreateTime_withdrawTimestamp.in[0] <== utxoOutCreateTime;
    isLessThanEq_utxoOutCreateTime_withdrawTimestamp.in[1] <== kytWithdrawSignedMessageTimestamp + zZoneKytExpiryTime;

    // [27] - Verify static-merkle-root
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

    // [28] - Verify forest-merkle-roots
    component forestTreeMerkleRootVerifier = Poseidon(3);
    forestTreeMerkleRootVerifier.inputs[0] <== taxiMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[1] <== busMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[2] <== ferryMerkleRoot;

    // verify computed root against provided one
    component isEqualForestTreeMerkleRoot = ForceEqualIfEnabled();
    isEqualForestTreeMerkleRoot.in[0] <== forestTreeMerkleRootVerifier.out;
    isEqualForestTreeMerkleRoot.in[1] <== forestMerkleRoot;
    isEqualForestTreeMerkleRoot.enabled <== forestMerkleRoot;

    // [29] - Verify salt
    component saltVerify = Poseidon(1);
    saltVerify.inputs[0] <== salt;

    component isEqualSalt = ForceEqualIfEnabled();
    isEqualSalt.in[0] <== saltVerify.out;
    isEqualSalt.in[1] <== saltHash;
    isEqualSalt.enabled <== saltHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [30] - Magical Constraint check ///////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [31] - Range check ////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component zTransactionV1RC = ZTransactionV1RangeCheck ( nUtxoIn,
                                                            nUtxoOut,
                                                            UtxoLeftMerkleTreeDepth,
                                                            UtxoMiddleMerkleTreeDepth,
                                                            ZNetworkMerkleTreeDepth,
                                                            ZAssetMerkleTreeDepth,
                                                            ZAccountBlackListMerkleTreeDepth,
                                                            ZZoneMerkleTreeDepth,
                                                            TrustProvidersMerkleTreeDepth );

    zTransactionV1RC.extraInputsHash <== extraInputsHash;
    zTransactionV1RC.depositAmount <== depositAmount;
    zTransactionV1RC.withdrawAmount <== withdrawAmount;
    zTransactionV1RC.addedAmountZkp <== addedAmountZkp;
    zTransactionV1RC.token <== token;
    zTransactionV1RC.tokenId <== tokenId;
    zTransactionV1RC.utxoZAsset <== utxoZAsset;

    zTransactionV1RC.zAssetId <== zAssetId;
    zTransactionV1RC.zAssetToken <== zAssetToken;
    zTransactionV1RC.zAssetTokenId <== zAssetTokenId;
    zTransactionV1RC.zAssetNetwork <== zAssetNetwork;
    zTransactionV1RC.zAssetOffset <== zAssetOffset;
    zTransactionV1RC.zAssetWeight <== zAssetWeight;
    zTransactionV1RC.zAssetScale <== zAssetScale;
    zTransactionV1RC.zAssetMerkleRoot <== zAssetMerkleRoot;
    zTransactionV1RC.zAssetPathIndices <== zAssetPathIndices;
    zTransactionV1RC.zAssetPathElements <== zAssetPathElements;

    zTransactionV1RC.zAssetIdZkp <== zAssetIdZkp;
    zTransactionV1RC.zAssetTokenZkp <== zAssetTokenZkp;
    zTransactionV1RC.zAssetTokenIdZkp <== zAssetTokenIdZkp;
    zTransactionV1RC.zAssetNetworkZkp <== zAssetNetworkZkp;
    zTransactionV1RC.zAssetOffsetZkp <== zAssetOffsetZkp;
    zTransactionV1RC.zAssetWeightZkp <== zAssetWeightZkp;
    zTransactionV1RC.zAssetScaleZkp <== zAssetScaleZkp;
    zTransactionV1RC.zAssetPathIndicesZkp <== zAssetPathIndicesZkp;
    zTransactionV1RC.zAssetPathElementsZkp <== zAssetPathElementsZkp;

    zTransactionV1RC.forTxReward <== forTxReward;
    zTransactionV1RC.forUtxoReward <== forUtxoReward;
    zTransactionV1RC.forDepositReward <== forDepositReward;
    zTransactionV1RC.spendTime <== spendTime;

    zTransactionV1RC.utxoInSpendPrivKey <== utxoInSpendPrivKey;
    zTransactionV1RC.utxoInSpendKeyRandom <== utxoInSpendKeyRandom;
    zTransactionV1RC.utxoInAmount <== utxoInAmount;
    zTransactionV1RC.utxoInOriginZoneId <== utxoInOriginZoneId;
    zTransactionV1RC.utxoInOriginZoneIdOffset <== utxoInOriginZoneIdOffset;
    zTransactionV1RC.utxoInOriginNetworkId <== utxoInOriginNetworkId;
    zTransactionV1RC.utxoInTargetNetworkId <== utxoInTargetNetworkId;
    zTransactionV1RC.utxoInCreateTime <== utxoInCreateTime;
    zTransactionV1RC.utxoInZAccountId <== utxoInZAccountId;
    zTransactionV1RC.utxoInMerkleTreeSelector <== utxoInMerkleTreeSelector;
    zTransactionV1RC.utxoInPathIndices <== utxoInPathIndices;
    zTransactionV1RC.utxoInPathElements <== utxoInPathElements;
    zTransactionV1RC.utxoInNullifier <== utxoInNullifier;
    zTransactionV1RC.utxoInDataEscrowPubKey <== utxoInDataEscrowPubKey;

    zTransactionV1RC.zAccountUtxoInId <== zAccountUtxoInId;
    zTransactionV1RC.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    zTransactionV1RC.zAccountUtxoInPrpAmount <== zAccountUtxoInPrpAmount;
    zTransactionV1RC.zAccountUtxoInZoneId <== zAccountUtxoInZoneId;
    zTransactionV1RC.zAccountUtxoInNetworkId <== zAccountUtxoInNetworkId;
    zTransactionV1RC.zAccountUtxoInExpiryTime <== zAccountUtxoInExpiryTime;
    zTransactionV1RC.zAccountUtxoInNonce <== zAccountUtxoInNonce;
    zTransactionV1RC.zAccountUtxoInTotalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zTransactionV1RC.zAccountUtxoInCreateTime <== zAccountUtxoInCreateTime;
    zTransactionV1RC.zAccountUtxoInRootSpendPubKey <== zAccountUtxoInRootSpendPubKey;
    zTransactionV1RC.zAccountUtxoInReadPubKey <== zAccountUtxoInReadPubKey;
    zTransactionV1RC.zAccountUtxoInNullifierPubKey <== zAccountUtxoInNullifierPubKey;
    zTransactionV1RC.zAccountUtxoInMasterEOA <== zAccountUtxoInMasterEOA;
    zTransactionV1RC.zAccountUtxoInSpendPrivKey <== zAccountUtxoInSpendPrivKey;
    zTransactionV1RC.zAccountUtxoInReadPrivKey <== zAccountUtxoInReadPrivKey;
    zTransactionV1RC.zAccountUtxoInNullifierPrivKey <== zAccountUtxoInNullifierPrivKey;
    zTransactionV1RC.zAccountUtxoInMerkleTreeSelector <== zAccountUtxoInMerkleTreeSelector;
    zTransactionV1RC.zAccountUtxoInPathIndices <== zAccountUtxoInPathIndices;
    zTransactionV1RC.zAccountUtxoInPathElements <== zAccountUtxoInPathElements;
    zTransactionV1RC.zAccountUtxoInNullifier <== zAccountUtxoInNullifier;

    zTransactionV1RC.zAccountBlackListLeaf <== zAccountBlackListLeaf;
    zTransactionV1RC.zAccountBlackListMerkleRoot <== zAccountBlackListMerkleRoot;
    zTransactionV1RC.zAccountBlackListPathElements <== zAccountBlackListPathElements;
    zTransactionV1RC.zZoneOriginZoneIDs <== zZoneOriginZoneIDs;
    zTransactionV1RC.zZoneTargetZoneIDs <== zZoneTargetZoneIDs;
    zTransactionV1RC.zZoneNetworkIDsBitMap <== zZoneNetworkIDsBitMap;
    zTransactionV1RC.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zTransactionV1RC.zZoneKycExpiryTime <== zZoneKycExpiryTime;
    zTransactionV1RC.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    zTransactionV1RC.zZoneDepositMaxAmount <== zZoneDepositMaxAmount;
    zTransactionV1RC.zZoneWithrawMaxAmount <== zZoneWithrawMaxAmount;
    zTransactionV1RC.zZoneInternalMaxAmount <== zZoneInternalMaxAmount;
    zTransactionV1RC.zZoneMerkleRoot <== zZoneMerkleRoot;
    zTransactionV1RC.zZonePathElements <== zZonePathElements;
    zTransactionV1RC.zZonePathIndices <== zZonePathIndices;
    zTransactionV1RC.zZoneEdDsaPubKey <== zZoneEdDsaPubKey;
    zTransactionV1RC.zZoneDataEscrowEphemeralRandom <== zZoneDataEscrowEphemeralRandom;
    zTransactionV1RC.zZoneDataEscrowEphemeralPubKeyAx <== zZoneDataEscrowEphemeralPubKeyAx;
    zTransactionV1RC.zZoneDataEscrowEphemeralPubKeyAy <== zZoneDataEscrowEphemeralPubKeyAy;
    zTransactionV1RC.zZoneZAccountIDsBlackList <== zZoneZAccountIDsBlackList;
    zTransactionV1RC.zZoneMaximumAmountPerTimePeriod <== zZoneMaximumAmountPerTimePeriod;
    zTransactionV1RC.zZoneTimePeriodPerMaximumAmount <== zZoneTimePeriodPerMaximumAmount;
    zTransactionV1RC.zZoneDataEscrowEncryptedMessageAx <== zZoneDataEscrowEncryptedMessageAx;
    zTransactionV1RC.zZoneDataEscrowEncryptedMessageAy <== zZoneDataEscrowEncryptedMessageAy;
    zTransactionV1RC.zZoneSealing <== zZoneSealing;

    zTransactionV1RC.kytEdDsaPubKey <== kytEdDsaPubKey;
    zTransactionV1RC.kytEdDsaPubKeyExpiryTime <== kytEdDsaPubKeyExpiryTime;
    zTransactionV1RC.trustProvidersMerkleRoot <== trustProvidersMerkleRoot;
    zTransactionV1RC.kytPathElements <== kytPathElements;
    zTransactionV1RC.kytPathIndices <== kytPathIndices;
    zTransactionV1RC.kytMerkleTreeLeafIDsAndRulesOffset <== kytMerkleTreeLeafIDsAndRulesOffset;
    zTransactionV1RC.kytDepositSignedMessagePackageType <== kytDepositSignedMessagePackageType;
    zTransactionV1RC.kytDepositSignedMessageTimestamp <== kytDepositSignedMessageTimestamp;
    zTransactionV1RC.kytDepositSignedMessageSender <== kytDepositSignedMessageSender;
    zTransactionV1RC.kytDepositSignedMessageReceiver <== kytDepositSignedMessageReceiver;
    zTransactionV1RC.kytDepositSignedMessageToken <== kytDepositSignedMessageToken;
    zTransactionV1RC.kytDepositSignedMessageSessionId <== kytDepositSignedMessageSessionId;
    zTransactionV1RC.kytDepositSignedMessageRuleId <== kytDepositSignedMessageRuleId;
    zTransactionV1RC.kytDepositSignedMessageAmount <== kytDepositSignedMessageAmount;
    zTransactionV1RC.kytDepositSignedMessageChargedAmountZkp <== kytDepositSignedMessageChargedAmountZkp;
    zTransactionV1RC.kytDepositSignedMessageSigner <== kytDepositSignedMessageSigner;
    zTransactionV1RC.kytDepositSignedMessageHash <== kytDepositSignedMessageHash;
    zTransactionV1RC.kytDepositSignature <== kytDepositSignature;

    zTransactionV1RC.kytWithdrawSignedMessagePackageType <== kytWithdrawSignedMessagePackageType;
    zTransactionV1RC.kytWithdrawSignedMessageTimestamp <== kytWithdrawSignedMessageTimestamp;
    zTransactionV1RC.kytWithdrawSignedMessageSender <== kytWithdrawSignedMessageSender;
    zTransactionV1RC.kytWithdrawSignedMessageReceiver <== kytWithdrawSignedMessageReceiver;
    zTransactionV1RC.kytWithdrawSignedMessageToken <== kytWithdrawSignedMessageToken;
    zTransactionV1RC.kytWithdrawSignedMessageSessionId <== kytWithdrawSignedMessageSessionId;
    zTransactionV1RC.kytWithdrawSignedMessageRuleId <== kytWithdrawSignedMessageRuleId;
    zTransactionV1RC.kytWithdrawSignedMessageAmount <== kytWithdrawSignedMessageAmount;
    zTransactionV1RC.kytWithdrawSignedMessageChargedAmountZkp <== kytWithdrawSignedMessageChargedAmountZkp;
    zTransactionV1RC.kytWithdrawSignedMessageSigner <== kytWithdrawSignedMessageSigner;
    zTransactionV1RC.kytWithdrawSignedMessageHash <== kytWithdrawSignedMessageHash;
    zTransactionV1RC.kytWithdrawSignature <== kytWithdrawSignature;

    zTransactionV1RC.kytSignedMessagePackageType <== kytSignedMessagePackageType;
    zTransactionV1RC.kytSignedMessageTimestamp <== kytSignedMessageTimestamp;
    zTransactionV1RC.kytSignedMessageSessionId <== kytSignedMessageSessionId;
    zTransactionV1RC.kytSignedMessageChargedAmountZkp <== kytSignedMessageChargedAmountZkp;
    zTransactionV1RC.kytSignedMessageSigner <== kytSignedMessageSigner;
    zTransactionV1RC.kytSignedMessageDataEscrowHash <== kytSignedMessageDataEscrowHash;
    zTransactionV1RC.kytSignedMessageHash <== kytSignedMessageHash;
    zTransactionV1RC.kytSignature <== kytSignature;

    zTransactionV1RC.dataEscrowPubKey <== dataEscrowPubKey;
    zTransactionV1RC.dataEscrowPubKeyExpiryTime <== dataEscrowPubKeyExpiryTime;
    zTransactionV1RC.dataEscrowEphemeralRandom <== dataEscrowEphemeralRandom;
    zTransactionV1RC.dataEscrowEphemeralPubKeyAx <== dataEscrowEphemeralPubKeyAx;
    zTransactionV1RC.dataEscrowEphemeralPubKeyAy <== dataEscrowEphemeralPubKeyAy;
    zTransactionV1RC.dataEscrowPathElements <== dataEscrowPathElements;
    zTransactionV1RC.dataEscrowPathIndices <== dataEscrowPathIndices;

    zTransactionV1RC.dataEscrowEncryptedMessageAx <== dataEscrowEncryptedMessageAx;
    zTransactionV1RC.dataEscrowEncryptedMessageAy <== dataEscrowEncryptedMessageAy;

    zTransactionV1RC.daoDataEscrowPubKey <== daoDataEscrowPubKey;
    zTransactionV1RC.daoDataEscrowEphemeralRandom <== daoDataEscrowEphemeralRandom;
    zTransactionV1RC.daoDataEscrowEphemeralPubKeyAx <== daoDataEscrowEphemeralPubKeyAx;
    zTransactionV1RC.daoDataEscrowEphemeralPubKeyAy <== daoDataEscrowEphemeralPubKeyAy;

    zTransactionV1RC.daoDataEscrowEncryptedMessageAx <== daoDataEscrowEncryptedMessageAx;
    zTransactionV1RC.daoDataEscrowEncryptedMessageAy <== daoDataEscrowEncryptedMessageAy;

    zTransactionV1RC.utxoOutCreateTime <== utxoOutCreateTime;
    zTransactionV1RC.utxoOutAmount <== utxoOutAmount;
    zTransactionV1RC.utxoOutOriginNetworkId <== utxoOutOriginNetworkId;
    zTransactionV1RC.utxoOutTargetNetworkId <== utxoOutTargetNetworkId;
    zTransactionV1RC.utxoOutTargetZoneId <== utxoOutTargetZoneId;
    zTransactionV1RC.utxoOutTargetZoneIdOffset <== utxoOutTargetZoneIdOffset;
    zTransactionV1RC.utxoOutSpendPubKeyRandom <== utxoOutSpendPubKeyRandom;
    zTransactionV1RC.utxoOutRootSpendPubKey <== utxoOutRootSpendPubKey;
    zTransactionV1RC.utxoOutCommitment <== utxoOutCommitment;
    zTransactionV1RC.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    zTransactionV1RC.zAccountUtxoOutSpendKeyRandom <== zAccountUtxoOutSpendKeyRandom;
    zTransactionV1RC.zAccountUtxoOutCommitment <== zAccountUtxoOutCommitment;
    zTransactionV1RC.chargedAmountZkp <== chargedAmountZkp;

    zTransactionV1RC.zNetworkId <== zNetworkId;
    zTransactionV1RC.zNetworkChainId <== zNetworkChainId;
    zTransactionV1RC.zNetworkIDsBitMap <== zNetworkIDsBitMap;
    zTransactionV1RC.zNetworkTreeMerkleRoot <== zNetworkTreeMerkleRoot;
    zTransactionV1RC.zNetworkTreePathElements <== zNetworkTreePathElements;
    zTransactionV1RC.zNetworkTreePathIndices <== zNetworkTreePathIndices;

    zTransactionV1RC.staticTreeMerkleRoot <== staticTreeMerkleRoot;

    zTransactionV1RC.forestMerkleRoot <== forestMerkleRoot;
    zTransactionV1RC.taxiMerkleRoot <== taxiMerkleRoot;
    zTransactionV1RC.busMerkleRoot <== busMerkleRoot;
    zTransactionV1RC.ferryMerkleRoot <== ferryMerkleRoot;
    zTransactionV1RC.salt <== salt;
    zTransactionV1RC.saltHash <== saltHash;
    zTransactionV1RC.magicalConstraint <== magicalConstraint;
}
