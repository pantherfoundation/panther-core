//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

// project deps
include "./templates/balanceChecker.circom";
include "./templates/dataEscrowElgamalEncryption.circom";
include "./templates/isNotZero.circom";
include "./templates/kycKytMerkleTreeLeafIdAndRuleInclusionProver.circom";
include "./templates/kycKytNoteInclusionProver.circom";
include "./templates/networkIdInclusionProver.circom";
include "./templates/nullifierHasher.circom";
include "./templates/pubKeyDeriver.circom";
include "./templates/publicInputHasherExtended.circom";
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

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template TransactionV1Extended( nUtxoIn,
                                nUtxoOut,
                                UtxoLeftMerkleTreeDepth,
                                UtxoMiddleMerkleTreeDepth,
                                ZNetworkMerkleTreeDepth,
                                ZAssetMerkleTreeDepth,
                                ZAccountBlackListMerkleTreeDepth,
                                ZZoneMerkleTreeDepth,
                                KycKytMerkleTreeDepth ) {
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

    // tx api
    signal input depositAmount;    // public
    signal input depositChange;    // public
    signal input withdrawAmount;   // public
    signal input withdrawChange;   // public
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
    signal input zAssetPathIndex[ZAssetMerkleTreeDepth];
    signal input zAssetPathElements[ZAssetMerkleTreeDepth];

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
    signal input utxoInPathIndex[nUtxoIn][UtxoMerkleTreeDepth];
    signal input utxoInPathElements[nUtxoIn][UtxoMerkleTreeDepth];
    signal input utxoInNullifier[nUtxoIn]; // public

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
    signal input zAccountUtxoInMasterEOA;
    signal input zAccountUtxoInSpendPrivKey;
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
    signal input zZoneDataEscrowEphimeralRandom;
    signal input zZoneDataEscrowEphimeralPubKeyAx; // public
    signal input zZoneDataEscrowEphimeralPubKeyAy;
    signal input zZoneZAccountIDsBlackList;
    signal input zZoneMaximumAmountPerTimePeriod;
    signal input zZoneTimePeriodPerMaximumAmount;

    var zZoneDataEscrowScalarSize = 1;
    var zZoneDataEscrowEncryptedPoints = zZoneDataEscrowScalarSize;
    signal input zZoneDataEscrowEncryptedMessageAx[zZoneDataEscrowEncryptedPoints]; // public
    signal input zZoneDataEscrowEncryptedMessageAy[zZoneDataEscrowEncryptedPoints];

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // switch-off control is used for internal tx
    signal input kytEdDsaPubKey[2];
    signal input kytEdDsaPubKeyExpiryTime;
    signal input kycKytMerkleRoot;                       // used both for kytSignature, DataEscrow, DaoDataEscrow
    signal input kytPathElements[KycKytMerkleTreeDepth];
    signal input kytPathIndex[KycKytMerkleTreeDepth];
    signal input kytMerkleTreeLeafIDsAndRulesOffset;     // used for both cases of deposit & withdraw
    // deposit case
    signal input kytDepositSignedMessagePackageType;
    signal input kytDepositSignedMessageTimestamp;
    signal input kytDepositSignedMessageSender;
    signal input kytDepositSignedMessageReceiver;
    signal input kytDepositSignedMessageToken;
    signal input kytDepositSignedMessageSessionId;
    signal input kytDepositSignedMessageRuleId;
    signal input kytDepositSignedMessageAmount;
    signal input kytDepositSignedMessageHash;                // public
    signal input kytDepositSignature[3];                     // S,R8x,R8y
    // withdraw case
    signal input kytWithdrawSignedMessagePackageType;
    signal input kytWithdrawSignedMessageTimestamp;
    signal input kytWithdrawSignedMessageSender;
    signal input kytWithdrawSignedMessageReceiver;
    signal input kytWithdrawSignedMessageToken;
    signal input kytWithdrawSignedMessageSessionId;
    signal input kytWithdrawSignedMessageRuleId;
    signal input kytWithdrawSignedMessageAmount;
    signal input kytWithdrawSignedMessageHash;                // public
    signal input kytWithdrawSignature[3];                     // S,R8x,R8y

    // data escrow
    signal input dataEscrowPubKey[2];
    signal input dataEscrowPubKeyExpiryTime;
    signal input dataEscrowEphimeralRandom;
    signal input dataEscrowEphimeralPubKeyAx; // public
    signal input dataEscrowEphimeralPubKeyAy;
    signal input dataEscrowPathElements[KycKytMerkleTreeDepth];
    signal input dataEscrowPathIndex[KycKytMerkleTreeDepth];

    // ------------- scalars-size --------------------------------
    // 1) 1 x 64 (zAsset)
    // 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
    // 3) nUtxoIn x 64 amount
    // 4) nUtxoOut x 64 amount
    // 5) MAX(nUtxoIn,nUtxoOut) x ( utxo-in-origin-zones-ids & utxo-out-target-zone-ids - 32 bit )
    // ------------- ec-points-size -------------
    // 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)

    var max_nUtxoIn_nUtxoOut = nUtxoIn > nUtxoOut ? nUtxoIn:nUtxoOut;
    var dataEscrowScalarSize = 1+1+nUtxoIn+nUtxoOut+max_nUtxoIn_nUtxoOut;
    var dataEscrowPointSize = nUtxoOut;
    var dataEscrowEncryptedPoints = dataEscrowScalarSize + dataEscrowPointSize;
    signal input dataEscrowEncryptedMessageAx[dataEscrowEncryptedPoints]; // public
    signal input dataEscrowEncryptedMessageAy[dataEscrowEncryptedPoints];

    // dao data escrow
    signal input daoDataEscrowPubKey[2];
    signal input daoDataEscrowEphimeralRandom;
    signal input daoDataEscrowEphimeralPubKeyAx; // public
    signal input daoDataEscrowEphimeralPubKeyAy;

    // ------------- scalars-size --------------
    // 1) 1 x 64 (zAccountId << 16 | zAccountZoneId)
    // 2) MAX(nUtxoIn,nUtxoOut) x 64 ( utxoInOriginZoneId << 16 | utxoOutTargetZoneId)
    // ------------- ec-points-size -------------
    // 1) 0
    var daoDataEscrowScalarSize = 1 + max_nUtxoIn_nUtxoOut;
    var daoDataEscrowEncryptedPoints = daoDataEscrowScalarSize;
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
    signal input zNetworkTreePathIndex[ZNetworkMerkleTreeDepth];

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
    totalBalanceChecker.depositChange <== depositChange;
    totalBalanceChecker.withdrawAmount <== withdrawAmount;
    totalBalanceChecker.withdrawChange <== withdrawChange;
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== totalUtxoInAmount;
    totalBalanceChecker.totalUtxoOutAmount <== totalUtxoOutAmount;
    totalBalanceChecker.zAssetWeight <== zAssetWeight;
    totalBalanceChecker.zAssetScale <== zAssetScale;

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
        zAssetNoteInclusionProver.pathIndex[i] <== zAssetPathIndex[i];
        zAssetNoteInclusionProver.pathElements[i] <== zAssetPathElements[i];
    }

    // verify zAsset::network is equal to the current networkId
    zAssetNetwork === zNetworkId;

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
        utxoInNoteHashers[i] = UtxoNoteHasher();
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
        utxoInNullifierHasher[i].spendPrivKey <== utxoInSpendPrivKey[i];
        utxoInNullifierHasher[i].leaf <== utxoInNoteHashers[i].out;
        // utxoInNullifier[i] === utxoInNullifierHasher[i].out;

        utxoInNullifierProver[i] = ForceEqualIfEnabled();
        utxoInNullifierProver[i].in[0] <== utxoInNullifier[i];
        utxoInNullifierProver[i].in[1] <== utxoInNullifierHasher[i].out;
        utxoInNullifierProver[i].enabled <== utxoInIsEnabled[i].out;

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
            utxoInInclusionProver[i].pathIndices[j] <== utxoInPathIndex[i][j];
        }
        // roots
        utxoInInclusionProver[i].root[0] <== taxiMerkleRoot;
        utxoInInclusionProver[i].root[1] <== busMerkleRoot;
        utxoInInclusionProver[i].root[2] <== ferryMerkleRoot;

        // switch-on membership if amount != 0, otherwise switch-off
        utxoInInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify zone max internal limits
        assert(zZoneInternalMaxAmount >= (utxoInAmount[i] * zAssetWeight));
    }

    // [6] - Verify output notes and compute total amount of output 'zAsset UTXOs'
    component utxoOutNoteHasher[nUtxoOut];
    component utxoOutCommitmentProver[nUtxoIn];
    component utxoOutSpendPubKeyDeriver[nUtxoOut];
    component utxoOutOriginNetworkIdInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdInclusionProver[nUtxoOut];
    component utxoOutOriginNetworkIdZNetoworkInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdZNetoworkInclusionProver[nUtxoOut];
    component utxoOutZoneIdInclusionProver[nUtxoOut];
    component utxoOutIsEnabled[nUtxoOut];

    for (var i = 0; i < nUtxoOut; i++){
        // derive spending pubkey from root-spend-pubkey (anchor to zAccount)
        utxoOutSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoOutSpendPubKeyDeriver[i].rootPubKey[0] <== utxoOutRootSpendPubKey[i][0];
        utxoOutSpendPubKeyDeriver[i].rootPubKey[1] <== utxoOutRootSpendPubKey[i][1];
        utxoOutSpendPubKeyDeriver[i].random <== utxoOutSpendPubKeyRandom[i]; // random generated by sender

        // verify commitment
        utxoOutNoteHasher[i] = UtxoNoteHasher();
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
        // utxoOutCommitment[i] === utxoOutNoteHasher[i].out;

        // is-zero amount check
        utxoOutIsEnabled[i] = IsNotZero();
        utxoOutIsEnabled[i].in <== utxoOutAmount[i];

        utxoOutCommitmentProver[i] = ForceEqualIfEnabled();
        utxoOutCommitmentProver[i].in[0] <== utxoOutCommitment[i];
        utxoOutCommitmentProver[i].in[1] <== utxoOutNoteHasher[i].out;
        utxoOutCommitmentProver[i].enabled <== utxoOutIsEnabled[i].out;

        // verify if target zoneId is allowed in zZone (originZoneId vefiried via zAccount)
        utxoOutZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoOutZoneIdInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutZoneIdInclusionProver[i].zoneId <== utxoOutTargetZoneId[i];
        utxoOutZoneIdInclusionProver[i].zoneIds <== zZoneTargetZoneIDs;
        utxoOutZoneIdInclusionProver[i].offset <== utxoOutTargetZoneIdOffset[i];

        // verify origin networkId is allowed in zZone
        utxoOutOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutOriginNetworkIdInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutOriginNetworkIdInclusionProver[i].networkId <== utxoOutOriginNetworkId[i];
        utxoOutOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;

        // verify target networkId is allowed in zZone
        utxoOutTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutTargetNetworkIdInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;

        // verify origin networkId is allowed (same as zNetworkId) in zNetwork
        utxoOutOriginNetworkIdZNetoworkInclusionProver[i] = ForceEqualIfEnabled();
        utxoOutOriginNetworkIdZNetoworkInclusionProver[i].in[0] <== zNetworkId;
        utxoOutOriginNetworkIdZNetoworkInclusionProver[i].in[1] <== utxoOutOriginNetworkId[i];
        utxoOutOriginNetworkIdZNetoworkInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;

        // verify target networkId is allowed in zNetwork
        utxoOutTargetNetworkIdZNetoworkInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdZNetoworkInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutTargetNetworkIdZNetoworkInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdZNetoworkInclusionProver[i].networkIdsBitMap <== zNetworkIDsBitMap;

        // verify zone max internal limits
        assert(zZoneInternalMaxAmount >= (utxoOutAmount[i] * zAssetWeight));

    }

    // [7] - Verify zZone max amount per time period
    assert(utxoOutCreateTime >= zAccountUtxoInCreateTime);
    signal deltaTime <== utxoOutCreateTime - zAccountUtxoInCreateTime;

    component isDeltaTimeLessEqThen = LessEqThan(252); // 1 if deltaTime <= zZoneTimePeriodPerMaximumAmount
    isDeltaTimeLessEqThen.in[0] <== deltaTime;
    isDeltaTimeLessEqThen.in[1] <== zZoneTimePeriodPerMaximumAmount;

    signal zAccountUtxoOutTotalAmountPerTimePeriod <== totalBalanceChecker.totalWeighted + (isDeltaTimeLessEqThen.out * zAccountUtxoInTotalAmountPerTimePeriod);
    // verify
    assert(zAccountUtxoOutTotalAmountPerTimePeriod <= zZoneMaximumAmountPerTimePeriod);

    // [8] - Verify input 'zAccount UTXO input'
    component zAccountUtxoInSpendPubKey = BabyPbk();
    zAccountUtxoInSpendPubKey.in <== zAccountUtxoInSpendPrivKey;

    component zAccountUtxoInHasher = ZAccountNoteHasher();
    zAccountUtxoInHasher.spendPubKey[0] <== zAccountUtxoInSpendPubKey.Ax;
    zAccountUtxoInHasher.spendPubKey[1] <== zAccountUtxoInSpendPubKey.Ay;
    zAccountUtxoInHasher.rootSpendPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoInHasher.rootSpendPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
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
    component zAccountUtxoInNullifierHasher = ZAccountNullifierHasher();
    zAccountUtxoInNullifierHasher.spendPrivKey <== zAccountUtxoInSpendPrivKey;
    zAccountUtxoInNullifierHasher.commitment <== zAccountUtxoInHasher.out;
    // zAccountUtxoInNullifier === zAccountUtxoInNullifierHasher.out;

    component zAccountUtxoInNullifierHasherProver = ForceEqualIfEnabled();
    zAccountUtxoInNullifierHasherProver.in[0] <== zAccountUtxoInNullifier;
    zAccountUtxoInNullifierHasherProver.in[1] <== zAccountUtxoInNullifierHasher.out;
    zAccountUtxoInNullifierHasherProver.enabled <== zAccountUtxoInSpendPrivKey;

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
    // zAccountUtxoOutCommitment === zAccountUtxoOutHasher.out;

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

    // [14] - Verify KYT signature, TODO: verify - token, amount, packageType and ruleId
    component isZeroDeposit = IsZero();
    isZeroDeposit.in <== depositAmount;

    component isZeroWithdraw = IsZero();
    isZeroWithdraw.in <== withdrawAmount;

    component isKytCheckEnabled = OR(); // result = a+b - a*b
    isKytCheckEnabled.a <== 1 - isZeroDeposit.out;
    isKytCheckEnabled.b <== 1 - isZeroWithdraw.out;

    var isKytDepositCheckEnabled = 1 - isZeroDeposit.out;

    component kytDepositSignedMessageHashInternal = Poseidon(8);

    kytDepositSignedMessageHashInternal.inputs[0] <== kytDepositSignedMessagePackageType;
    kytDepositSignedMessageHashInternal.inputs[1] <== kytDepositSignedMessageTimestamp;
    kytDepositSignedMessageHashInternal.inputs[2] <== kytDepositSignedMessageSender;
    kytDepositSignedMessageHashInternal.inputs[3] <== kytDepositSignedMessageReceiver;
    kytDepositSignedMessageHashInternal.inputs[4] <== kytDepositSignedMessageToken;
    kytDepositSignedMessageHashInternal.inputs[5] <== kytDepositSignedMessageSessionId;
    kytDepositSignedMessageHashInternal.inputs[6] <== kytDepositSignedMessageRuleId;
    kytDepositSignedMessageHashInternal.inputs[7] <== kytDepositSignedMessageAmount;

    component kytDepositSignatureVerifier = EdDSAPoseidonVerifier();
    kytDepositSignatureVerifier.enabled <== isKytDepositCheckEnabled;
    kytDepositSignatureVerifier.Ax <== kytEdDsaPubKey[0];
    kytDepositSignatureVerifier.Ay <== kytEdDsaPubKey[1];
    kytDepositSignatureVerifier.S <== kytDepositSignature[0];
    kytDepositSignatureVerifier.R8x <== kytDepositSignature[1];
    kytDepositSignatureVerifier.R8y <== kytDepositSignature[2];

    kytDepositSignatureVerifier.M <== kytDepositSignedMessageHashInternal.out;

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

    var isKytWithdrawCheckEnabled = 1 - isZeroWithdraw.out;

    component kytWithdrawSignedMessageHashInternal = Poseidon(8);

    kytWithdrawSignedMessageHashInternal.inputs[0] <== kytWithdrawSignedMessagePackageType;
    kytWithdrawSignedMessageHashInternal.inputs[1] <== kytWithdrawSignedMessageTimestamp;
    kytWithdrawSignedMessageHashInternal.inputs[2] <== kytWithdrawSignedMessageSender;
    kytWithdrawSignedMessageHashInternal.inputs[3] <== kytWithdrawSignedMessageReceiver;
    kytWithdrawSignedMessageHashInternal.inputs[4] <== kytWithdrawSignedMessageToken;
    kytWithdrawSignedMessageHashInternal.inputs[5] <== kytWithdrawSignedMessageSessionId;
    kytWithdrawSignedMessageHashInternal.inputs[6] <== kytWithdrawSignedMessageRuleId;
    kytWithdrawSignedMessageHashInternal.inputs[7] <== kytWithdrawSignedMessageAmount;

    component kytWithdrawSignatureVerifier = EdDSAPoseidonVerifier();
    kytWithdrawSignatureVerifier.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawSignatureVerifier.Ax <== kytEdDsaPubKey[0];
    kytWithdrawSignatureVerifier.Ay <== kytEdDsaPubKey[1];
    kytWithdrawSignatureVerifier.S <== kytWithdrawSignature[0];
    kytWithdrawSignatureVerifier.R8x <== kytWithdrawSignature[1];
    kytWithdrawSignatureVerifier.R8y <== kytWithdrawSignature[2];

    kytWithdrawSignatureVerifier.M <== kytWithdrawSignedMessageHashInternal.out;

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

    // [15] - Verify kytEdDSA public key membership
    component kytKycNoteInclusionProver = KycKytNoteInclusionProver(KycKytMerkleTreeDepth);
    kytKycNoteInclusionProver.enabled <== isKytCheckEnabled.out;
    kytKycNoteInclusionProver.root <== kycKytMerkleRoot;
    kytKycNoteInclusionProver.key[0] <== kytEdDsaPubKey[0];
    kytKycNoteInclusionProver.key[1] <== kytEdDsaPubKey[1];
    kytKycNoteInclusionProver.expiryTime <== kytEdDsaPubKeyExpiryTime;
    for (var j=0; j< KycKytMerkleTreeDepth; j++) {
        kytKycNoteInclusionProver.pathIndex[j] <== kytPathIndex[j];
        kytKycNoteInclusionProver.pathElements[j] <== kytPathElements[j];
    }

    // [16] - Verify kyt leaf-id & rule allowed in zZone - required if deposit or withdraw != 0
    component b2nLeafId = Bits2Num(KycKytMerkleTreeDepth);
    for (var j = 0; j < KycKytMerkleTreeDepth; j++) {
        b2nLeafId.in[j] <== kytPathIndex[j];
    }
    // deposit part
    component kytDepositLeafIdAndRuleInclusionProver = KycKytMerkleTreeLeafIDAndRuleInclusionProver();
    kytDepositLeafIdAndRuleInclusionProver.enabled <== isKytDepositCheckEnabled;
    kytDepositLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kytDepositLeafIdAndRuleInclusionProver.rule <== kytDepositSignedMessageRuleId;
    kytDepositLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneKycKytMerkleTreeLeafIDsAndRulesList;
    kytDepositLeafIdAndRuleInclusionProver.offset <== kytMerkleTreeLeafIDsAndRulesOffset;
    // withdraw part
    component kytWithdrawLeafIdAndRuleInclusionProver = KycKytMerkleTreeLeafIDAndRuleInclusionProver();
    kytWithdrawLeafIdAndRuleInclusionProver.enabled <== isKytWithdrawCheckEnabled;
    kytWithdrawLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kytWithdrawLeafIdAndRuleInclusionProver.rule <== kytWithdrawSignedMessageRuleId;
    kytWithdrawLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zZoneKycKytMerkleTreeLeafIDsAndRulesList;
    kytWithdrawLeafIdAndRuleInclusionProver.offset <== kytMerkleTreeLeafIDsAndRulesOffset;

    // [17] - Verify DataEscrow public key membership
    component isDataEscrowInclusionProverEnabled = IsNotZero();
    isDataEscrowInclusionProverEnabled.in <== kycKytMerkleRoot;

    component dataEscrowInclusionProver = KycKytNoteInclusionProver(KycKytMerkleTreeDepth);
    dataEscrowInclusionProver.enabled <== isDataEscrowInclusionProverEnabled.out; // 1; // TODO:FIXME - enabled in any case
    dataEscrowInclusionProver.root <== kycKytMerkleRoot;
    dataEscrowInclusionProver.key[0] <== dataEscrowPubKey[0];
    dataEscrowInclusionProver.key[1] <== dataEscrowPubKey[1];
    dataEscrowInclusionProver.expiryTime <== dataEscrowPubKeyExpiryTime;

    for (var j = 0; j < KycKytMerkleTreeDepth; j++) {
        dataEscrowInclusionProver.pathIndex[j] <== dataEscrowPathIndex[j];
        dataEscrowInclusionProver.pathElements[j] <== dataEscrowPathElements[j];
    }

    // [18] - Data Escrow encryption
    // ------------- scalars-size --------------
    // 1) 1 x 64 (zAsset)
    // 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
    // 3) nUtxoIn x 64 amount
    // 4) nUtxoOut x 64 amount
    // 5) MAX(nUtxoIn,nUtxoOut) x ( utxo-in-origin-zones-ids & utxo-out-target-zone-ids - 32 bit )
    // ------------- ec-points-size -------------
    // 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)
    component dataEscrow = DataEscrowElGamalEncryption(dataEscrowScalarSize,dataEscrowPointSize);

    dataEscrow.ephimeralRandom <== dataEscrowEphimeralRandom;
    dataEscrow.pubKey[0] <== dataEscrowPubKey[0];
    dataEscrow.pubKey[1] <== dataEscrowPubKey[1];

    // --------------- scalars -----------------
    component dataEscrowScalarsSerializer = DataEscrowSerializer(nUtxoIn,nUtxoOut);
    dataEscrowScalarsSerializer.zAsset <== utxoZAsset;
    dataEscrowScalarsSerializer.zAccountId <== zAccountUtxoInId;
    dataEscrowScalarsSerializer.zAccountZoneId <== zAccountUtxoInZoneId;

    for (var j = 0; j < nUtxoIn; j++) {
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

    // verify EphimeralPubKey
    dataEscrowEphimeralPubKeyAx === dataEscrow.ephimeralPubKey[0];
    dataEscrowEphimeralPubKeyAy === dataEscrow.ephimeralPubKey[1];

    // verify Encryption
    for (var i = 0; i < dataEscrowEncryptedPoints; i++) {
        dataEscrowEncryptedMessageAx[i] === dataEscrow.encryptedMessage[i][0];
        dataEscrowEncryptedMessageAy[i] === dataEscrow.encryptedMessage[i][1];
    }

    // [19] - DAO Data Escrow encryption
    component daoDataEscrow = DataEscrowElGamalEncryptionScalar(daoDataEscrowScalarSize);

    daoDataEscrow.ephimeralRandom <== daoDataEscrowEphimeralRandom;
    daoDataEscrow.pubKey[0] <== daoDataEscrowPubKey[0];
    daoDataEscrow.pubKey[1] <== daoDataEscrowPubKey[1];

    component daoDataEscrowScalarsSerializer = DaoDataEscrowSerializer(nUtxoIn,nUtxoOut);

    daoDataEscrowScalarsSerializer.zAccountId <== zAccountUtxoInId;
    daoDataEscrowScalarsSerializer.zAccountZoneId <== zAccountUtxoInZoneId;

    for (var j = 0; j < nUtxoIn; j++) {
        daoDataEscrowScalarsSerializer.utxoInOriginZoneId[j] <== utxoInOriginZoneId[j];
    }

    for (var j = 0; j < nUtxoOut; j++) {
        daoDataEscrowScalarsSerializer.utxoOutTargetZoneId[j] <== utxoOutTargetZoneId[j];
    }

    for (var j = 0; j < daoDataEscrowScalarSize; j++) {
        daoDataEscrow.scalarMessage[j] <== daoDataEscrowScalarsSerializer.out[j];
    }

    // verify EphimeralPubKey
    daoDataEscrowEphimeralPubKeyAx === daoDataEscrow.ephimeralPubKey[0];
    daoDataEscrowEphimeralPubKeyAy === daoDataEscrow.ephimeralPubKey[1];

    // verify Encryption
    for (var i = 0; i < daoDataEscrowEncryptedPoints; i++) {
       daoDataEscrowEncryptedMessageAx[i] === daoDataEscrow.encryptedMessage[i][0];
       daoDataEscrowEncryptedMessageAy[i] === daoDataEscrow.encryptedMessage[i][1];
    }

    // [20] - Verify zZone membership
    component zZoneNoteHasher = ZZoneNoteHasher();
    zZoneNoteHasher.zoneId <== zAccountUtxoInZoneId;
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

    // [21] - Verify zZone max external limits
    assert(zZoneDepositMaxAmount >= totalBalanceChecker.depositWeightedScaledAmount);
    assert(zZoneWithrawMaxAmount >= totalBalanceChecker.withdrawWeightedScaledAmount);

    // [22] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountUtxoInId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [23] - zAccountId data escrow for zone operator
    component zZoneDataEscrow = DataEscrowElGamalEncryptionScalar(zZoneDataEscrowScalarSize);

    zZoneDataEscrow.ephimeralRandom <== zZoneDataEscrowEphimeralRandom;
    zZoneDataEscrow.pubKey[0] <== zZoneEdDsaPubKey[0];
    zZoneDataEscrow.pubKey[1] <== zZoneEdDsaPubKey[1];
    zZoneDataEscrow.scalarMessage[0] <== zAccountUtxoInId;

    // verify EphimeralPubKey
    zZoneDataEscrowEphimeralPubKeyAx === zZoneDataEscrow.ephimeralPubKey[0];
    zZoneDataEscrowEphimeralPubKeyAy === zZoneDataEscrow.ephimeralPubKey[1];

    // verify Encryption
    for (var i = 0; i < zZoneDataEscrowEncryptedPoints; i++) {
        zZoneDataEscrowEncryptedMessageAx[i] === zZoneDataEscrow.encryptedMessage[i][0];
        zZoneDataEscrowEncryptedMessageAy[i] === zZoneDataEscrow.encryptedMessage[i][1];
    }

    // [24] - Verify zAsset's membership and decode its weight
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

    // [25] - verify expiryTimes
    assert(zAccountUtxoInExpiryTime >= utxoOutCreateTime);
    assert(kytEdDsaPubKeyExpiryTime >= utxoOutCreateTime);
    assert(dataEscrowPubKeyExpiryTime >= utxoOutCreateTime);
    assert(kytDepositSignedMessageTimestamp + zZoneKytExpiryTime >= utxoOutCreateTime);
    assert(kytWithdrawSignedMessageTimestamp + zZoneKytExpiryTime >= utxoOutCreateTime);

    // [26] - Verify static-merkle-root
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

    // [27] - Verify forest-merkle-roots
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

    // [28] - Verify salt
    component saltVerify = Poseidon(1);
    saltVerify.inputs[0] <== salt;

    component isEqualSalt = ForceEqualIfEnabled();
    isEqualSalt.in[0] <== saltVerify.out;
    isEqualSalt.in[1] <== saltHash;
    isEqualSalt.enabled <== saltHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [29] - Magical Contraint check ////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;
}
