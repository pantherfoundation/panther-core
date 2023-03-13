//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

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
include "./templates/zoneIdInclusionProver.circom";
include "./templates/zoneRecordNoteHasher.circom";
include "./templates/zoneRecordNoteInclusionProver.circom";

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template TransactionV1Extended( nUtxoIn,
                                nUtxoOut,
                                nKytSignedMessage,
                                UtxoMerkleTreeDepth,
                                ZAssetMerkleTreeDepth,
                                ZAccountBlackListMerkleTreeDepth,
                                ZoneRecordsMerkleTreeDepth,
                                KycKytMerkleTreeDepth ) {

    // internal data anchoring - signle EXPLICITLY public
    signal input publicInputsHash; // public

    // external data anchoring
    signal input extraInputsHash;  // public

    // tx api
    signal input publicZAsset;     // public - address made from `zAsset` for a deposit/withdraw, zero otherwise
    signal input depositAmount;    // public - in zAsset units, non-zero for a deposit
    signal input withdrawAmount;   // public - in zAsset units, non-zero for a withdrawal
    signal input privateZAsset;

    // zAsset weight
    signal input zAssetWeight;
    signal input zAssetMerkleRoot; // public
    signal input zAssetPathIndex[ZAssetMerkleTreeDepth];
    signal input zAssetPathElements[ZAssetMerkleTreeDepth];

    // reward computation params
    signal input forTxReward;      // public
    signal input forUtxoReward;    // public
    signal input forDepositReward; // public
    signal input spendTime;        // public

    // input 'zAsset UTXOs'
    // to switch-off:
    //      1) utxoInAmount = 0
    //      2) utxoInSpendPrivKey = 0
    //      3) utxoInRootSpendPrivKey = 0
    // switch-off control is used for:
    //      1) deposit only tx
    //      2) deposit & zAccount::zkpAmount
    //      3) deposit & zAccount::zkpAmount & withdraw
    //      4) deposit & withrdaw
    signal input utxoInSpendPrivKey[nUtxoIn];
    signal input utxoInRootSpendPrivKey[nUtxoIn];
    signal input utxoInAmount[nUtxoIn];
    signal input utxoInOriginZoneId[nUtxoIn];
    signal input utxoInOriginZoneIdOffset[nUtxoIn];
    signal input utxoInOriginNetworkId[nUtxoIn];
    signal input utxoInTargetNetworkId[nUtxoIn];
    signal input utxoInCreateTime[nUtxoIn];
    signal input utxoInTreeNumber[nUtxoIn];
    signal input utxoInMerkleRoot[nUtxoIn]; // public
    signal input utxoInPathIndex[nUtxoIn][UtxoMerkleTreeDepth+1];
    signal input utxoInPathElements[nUtxoIn][UtxoMerkleTreeDepth+1]; // extra slot for the third leave

    // input 'zAccount UTXO' TODO:FIXME - implement masp-internal-tx-freq-limit
    signal input zAccountUtxoInId;
    signal input zAccountUtxoInZkpAmount;
    signal input zAccountUtxoInPrpAmount;
    signal input zAccountUtxoInZoneId;
    signal input zAccountUtxoInExpiryTime;
    signal input zAccountUtxoInNonce;
    signal input zAccountUtxoInTreeNumber;
    signal input zAccountUtxoInRootSpendPubKey[2];
    signal input zAccountUtxoInMasterEOA;
    signal input zAccountUtxoInSpendPrivKey;
    signal input zAccountUtxoInMerkleRoot; // public
    signal input zAccountUtxoInPathIndices[UtxoMerkleTreeDepth+1];
    signal input zAccountUtxoInPathElements[UtxoMerkleTreeDepth+1]; // extra slot for the third leave

    // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
    signal input zAccountBlackListLeaf;
    signal input zAccountBlackListMerkleRoot; // public
    signal input zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth];

    // zAccountZoneRecord
    signal input zoneRecordOriginZonesList;
    signal input zoneRecordTargetZonesList;
    signal input zoneRecordNetworkIDsBitMap;
    signal input zoneRecordKycKytMerkleTreeLeafIDsAndRulesList;
    signal input zoneRecordKycExpiryTime;
    signal input zoneRecordKytExpiryTime;
    signal input zoneRecordDepositMaxAmount;
    signal input zoneRecordWithrawMaxAmount;
    signal input zoneRecordInternalMaxAmount;
    signal input zoneRecordMerkleRoot; // public
    signal input zoneRecordPathElements[ZoneRecordsMerkleTreeDepth];
    signal input zoneRecordPathIndex[ZoneRecordsMerkleTreeDepth];
    signal input zoneRecordEdDsaPubKey[2];
    signal input zoneRecordDataEscrowEphimeralRandom;
    signal input zoneRecordEcDsaPubKeyHash;

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // switch-off control is used for internal tx
    signal input kytEdDsaPubKey[2];
    signal input kytEdDsaPubKeyExpiryTime;
    signal input kytSignedMessage[nKytSignedMessage]; // TODO: FIXME - extract & use rules & build message preimage from public params
    signal input kytSignedMessageHash;                // public
    signal input kytSignature[3];                     // S,R8x,R8y
    signal input kycKytMerkleRoot;                    // public - used both for kytSignature, DataEscrow, DaoDataEscrow
    signal input kytPathElements[KycKytMerkleTreeDepth];
    signal input kytPathIndex[KycKytMerkleTreeDepth];
    signal input kytMerkleTreeLeafIDsAndRulesOffset;

    // data escrow
    signal input dataEscrowPubKey[2];
    signal input dataEscrowPubKeyExpiryTime;
    signal input dataEscrowEphimeralRandom;
    signal input dataEscrowPathElements[KycKytMerkleTreeDepth];
    signal input dataEscrowPathIndex[KycKytMerkleTreeDepth];

    // dao data escrow
    signal input daoDataEscrowPubKey[2]; // public
    signal input daoDataEscrowEphimeralRandom;

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
    signal input utxoOutOriginNetworkId[nUtxoOut]; // public - it is the network this UTXO is created at
    signal input utxoOutTargetNetworkId[nUtxoOut];
    signal input utxoOutTargetZoneId[nUtxoOut];
    signal input utxoOutTargetZoneIdOffset[nUtxoOut];
    signal input utxoOutSpendPubKeyRandom[nUtxoOut];
    signal input utxoOutRootSpendPubKey[nUtxoOut][2]; // TODO: FIXME - implement derivation check

    // output 'zAccount UTXO'
    signal input zAccountUtxoOutZkpAmount;
    signal input zAccountUtxoOutSpendKeyRandom;

    // output 'protocol + relayer fee in ZKP'
    signal input chargedAmountZkp; // public

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // START OF CODE /////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////

    // [0] - Check 'publicZAsset' & deposit / withdraw amounts
    component zAssetChecker = ZAssetChecker();
    zAssetChecker.publicZAsset <== publicZAsset;
    zAssetChecker.privateZAsset <== privateZAsset;
    zAssetChecker.depositAmount <== depositAmount;
    zAssetChecker.withdrawAmount <== withdrawAmount;

    // [1] - Verify zAsset's membership and decode its weight
    component zAssetNoteInclusionProver = ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth);
    zAssetNoteInclusionProver.zAsset <== privateZAsset;
    zAssetNoteInclusionProver.weight <== zAssetWeight;
    zAssetNoteInclusionProver.merkleRoot <== zAssetMerkleRoot;

    for (var i = 0; i < ZAssetMerkleTreeDepth; i++) {
        zAssetNoteInclusionProver.pathIndex[i] <== zAssetPathIndex[i];
        zAssetNoteInclusionProver.pathElements[i] <== zAssetPathElements[i];
    }

    // [2] - Pass values for computing rewards
    component rewards = RewardsExtended(nUtxoIn);
    rewards.depositAmount <== depositAmount;
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

    // [3] - Verify input notes, membership, compute total amount of input 'zAsset UTXOs'
    component utxoInNullifierHasher[nUtxoIn];
    component utxoInSpendPubKey[nUtxoIn];
    component utxoInSpendPubKeyDeriver[nUtxoIn];
    component utxoInNoteHashers[nUtxoIn];
    component utxoInInclusionProver[nUtxoIn];
    component utxoInOriginZoneIdInclusionProver[nUtxoIn];
    component utxoInOriginNetworkIdInclusionProver[nUtxoIn];
    component utxoInTargetNetworkIdInclusionProver[nUtxoIn];
    component utxoInIsEnabled[nUtxoIn];

    var totalUtxoInAmount = 0; // in zAsset units

    for (var i = 0 ; i < nUtxoIn; i++){

        // derive spending pubkey from root-spend-pubkey (anchor to zAccount)
        utxoInSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoInSpendPubKeyDeriver[i].rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
        utxoInSpendPubKeyDeriver[i].rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
        utxoInSpendPubKeyDeriver[i].random <== utxoInRootSpendPrivKey[i]; // random generated by sender

        // derive spending pubkey
        utxoInSpendPubKey[i] = BabyPbk();
        utxoInSpendPubKey[i].in <== utxoInSpendPrivKey[i]; // rootPrivKey * random

        // verify equality - can be switched-off by zero value of utxoInRootSpendPrivKey & utxoInSpendPrivKey
        utxoInSpendPubKey[i].Ax === utxoInSpendPubKeyDeriver[i].derivedPubKey[0];
        utxoInSpendPubKey[i].Ay === utxoInSpendPubKeyDeriver[i].derivedPubKey[1];

        // compute commitment
        utxoInNoteHashers[i] = UtxoNoteHasher();
        utxoInNoteHashers[i].spendPk[0] <== utxoInSpendPubKey[i].Ax;
        utxoInNoteHashers[i].spendPk[1] <== utxoInSpendPubKey[i].Ay;
        utxoInNoteHashers[i].zAsset <== privateZAsset;
        utxoInNoteHashers[i].amount <== utxoInAmount[i];
        utxoInNoteHashers[i].originNetworkId <== utxoInOriginNetworkId[i];
        utxoInNoteHashers[i].targetNetworkId <== utxoInTargetNetworkId[i];
        utxoInNoteHashers[i].createTime <== utxoInCreateTime[i];
        utxoInNoteHashers[i].originZoneId <== utxoInOriginZoneId[i];
        utxoInNoteHashers[i].targetZoneId <== zAccountUtxoInZoneId; // ALWAYS will be ZoneId of current zAccount

        // is-zero amount check
        utxoInIsEnabled[i] = IsNotZero();
        utxoInIsEnabled[i].in <== utxoInAmount[i];

        // verify if origin zoneId is allowed in zoneRecord
        utxoInOriginZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoInOriginZoneIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInOriginZoneIdInclusionProver[i].zoneId <== utxoInOriginZoneId[i];
        utxoInOriginZoneIdInclusionProver[i].zoneIds <== zoneRecordOriginZonesList;
        utxoInOriginZoneIdInclusionProver[i].offset <== utxoInOriginZoneIdOffset[i];

        // verify origin networkId is allowed in zoneRecord
        utxoInOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInOriginNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInOriginNetworkIdInclusionProver[i].networkId <== utxoInOriginNetworkId[i];
        utxoInOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zoneRecordNetworkIDsBitMap;

        // verify target networkId is allowed in zoneRecord
        utxoInTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInTargetNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;
        utxoInTargetNetworkIdInclusionProver[i].networkId <== utxoInTargetNetworkId[i];
        utxoInTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zoneRecordNetworkIDsBitMap;

        // verify nullifier (actual anchor will take place in public-hash)
        utxoInNullifierHasher[i] = NullifierHasherExtended();
        utxoInNullifierHasher[i].spendPrivKey <== utxoInSpendPrivKey[i];
        utxoInNullifierHasher[i].leaf <== utxoInNoteHashers[i].out;

        // verify Merkle proofs for input notes
        utxoInInclusionProver[i] = UtxoNoteInclusionProver(UtxoMerkleTreeDepth);
        // leaf in MerkleTree
        utxoInInclusionProver[i].note <== utxoInNoteHashers[i].out;
        for(var j = 0; j < UtxoMerkleTreeDepth+1; j++) {
            utxoInInclusionProver[i].pathElements[j] <== utxoInPathElements[i][j];
            utxoInInclusionProver[i].pathIndices[j] <== utxoInPathIndex[i][j];
        }
        utxoInInclusionProver[i].root <== utxoInMerkleRoot[i];
        // switch-on membership if amount != 0, otherwise switch-off
        utxoInInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify zone max internal limits
        assert(zoneRecordInternalMaxAmount >= utxoOutAmount[i]);

        // accumulate total
        totalUtxoInAmount += utxoInAmount[i];
    }

    // [4] - Verify output notes and compute total amount of output 'zAsset UTXOs'
    component utxoOutNoteHasher[nUtxoOut];
    component utxoOutSpendPubKeyDeriver[nUtxoOut];
    component utxoOutOriginNetworkIdInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdInclusionProver[nUtxoOut];
    component utxoOutZoneIdInclusionProver[nUtxoOut];
    component utxoOutIsEnabled[nUtxoOut];

    var totalUtxoOutAmount = 0; // in zAsset units

    for (var i = 0; i < nUtxoOut; i++){
        // derive spending pubkey from root-spend-pubkey (anchor to zAccount)
        utxoOutSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoOutSpendPubKeyDeriver[i].rootPubKey[0] <== utxoOutRootSpendPubKey[i][0];
        utxoOutSpendPubKeyDeriver[i].rootPubKey[1] <== utxoOutRootSpendPubKey[i][1];
        utxoOutSpendPubKeyDeriver[i].random <== utxoOutSpendPubKeyRandom[i]; // random generated by sender

        // verify commitment (actual anchor will take place inside public-hash)
        utxoOutNoteHasher[i] = UtxoNoteHasher();
        utxoOutNoteHasher[i].spendPk[0] <== utxoOutSpendPubKeyDeriver[i].derivedPubKey[0];
        utxoOutNoteHasher[i].spendPk[1] <== utxoOutSpendPubKeyDeriver[i].derivedPubKey[0];
        utxoOutNoteHasher[i].zAsset <== privateZAsset;
        utxoOutNoteHasher[i].amount <== utxoOutAmount[i];
        utxoOutNoteHasher[i].originNetworkId <== utxoOutOriginNetworkId[i];
        utxoOutNoteHasher[i].targetNetworkId <== utxoOutTargetNetworkId[i];
        utxoOutNoteHasher[i].createTime <== utxoOutCreateTime;
        utxoOutNoteHasher[i].originZoneId <== zAccountUtxoInZoneId; // ALWAYS will be ZoneId of current zAccount
        utxoOutNoteHasher[i].targetZoneId <== utxoOutTargetZoneId[i];

        // is-zero amount check
        utxoOutIsEnabled[i] = IsNotZero();
        utxoOutIsEnabled[i].in <== utxoOutAmount[i];

        // verify if target zoneId is allowed in zoneRecord (originZoneId vefiried via zAccount)
        utxoOutZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoOutZoneIdInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutZoneIdInclusionProver[i].zoneId <== utxoOutTargetZoneId[i];
        utxoOutZoneIdInclusionProver[i].zoneIds <== zoneRecordTargetZonesList;
        utxoOutZoneIdInclusionProver[i].offset <== utxoOutTargetZoneIdOffset[i];

        // verify origin networkId is allowed in zoneRecord
        utxoOutOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutOriginNetworkIdInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutOriginNetworkIdInclusionProver[i].networkId <== utxoOutOriginNetworkId[i];
        utxoOutOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zoneRecordNetworkIDsBitMap;

        // verify target networkId is allowed in zoneRecord
        utxoOutTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdInclusionProver[i].enabled <== utxoOutIsEnabled[i].out;
        utxoOutTargetNetworkIdInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zoneRecordNetworkIDsBitMap;

        // verify zone max internal limits
        assert(zoneRecordInternalMaxAmount >= utxoOutAmount[i]);

        // accumulate total
        totalUtxoOutAmount += utxoOutAmount[i];
    }

    // [5] - Check the overall balance of all inputs & outputs
    component totalBalanceChecker = BalanceChecker();
    totalBalanceChecker.isZkpToken <== zAssetChecker.isZkpToken;
    totalBalanceChecker.depositAmount <== depositAmount;
    totalBalanceChecker.withdrawAmount <== withdrawAmount;
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== totalUtxoInAmount;
    totalBalanceChecker.totalUtxoOutAmount <== totalUtxoOutAmount;

    // [6] - Verify input 'zAccount UTXO input'
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

    // [7] - Verify zAccountUtxoIn nullifier (actual anchor will take place in public-hash)
    component zAccountUtxoInNullifierHasher = ZAccountNullifierHasher();
    zAccountUtxoInNullifierHasher.spendPrivKey <== zAccountUtxoInSpendPrivKey;
    zAccountUtxoInNullifierHasher.commitment <== zAccountUtxoInHasher.out;

    // [8] - Verify zAccountUtxoIn membership
    component zAccountUtxoInMerkleVerifier = MerkleTreeInclusionProof(UtxoMerkleTreeDepth);
    zAccountUtxoInMerkleVerifier.leaf <== zAccountUtxoInHasher.out;
    for (var i = 0; i < UtxoMerkleTreeDepth+1; i++) {
        zAccountUtxoInMerkleVerifier.pathIndices[i] <== zAccountUtxoInPathIndices[i];
        zAccountUtxoInMerkleVerifier.pathElements[i] <== zAccountUtxoInPathElements[i];
    }
    zAccountUtxoInMerkleVerifier.root === zAccountUtxoInMerkleRoot;

    // [9] - Verify zAccountUtxoOut spend-pub-key is indeed derivation of zAccountRootSpendKey
    component zAccountUtxoOutPubKeyDeriver = PubKeyDeriver();
    zAccountUtxoOutPubKeyDeriver.rootPubKey[0] <== zAccountUtxoInRootSpendPubKey[0];
    zAccountUtxoOutPubKeyDeriver.rootPubKey[1] <== zAccountUtxoInRootSpendPubKey[1];
    zAccountUtxoOutPubKeyDeriver.random <== zAccountUtxoOutSpendKeyRandom;

    // [10] - Verify zAccountUtxoOut commitment (actual anchore will take place in public-hash)
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

    // [11] - Verify zAccoutId exclusion proof
    component zAccountBlackListInlcusionProver = ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.zAccountId <== zAccountUtxoInId;
    zAccountBlackListInlcusionProver.leaf <== zAccountBlackListLeaf;
    zAccountBlackListInlcusionProver.merkleRoot <== zAccountBlackListMerkleRoot;
    for (var j = 0; j < ZoneRecordsMerkleTreeDepth; j++) {
        zAccountBlackListInlcusionProver.pathElements[j] <== zAccountBlackListPathElements[j];
    }

    // [12] - Verify KYT signature
    component isZeroDeposit = IsZero();
    isZeroDeposit.in <== depositAmount;

    component isZeroWithdraw = IsZero();
    isZeroWithdraw.in <== withdrawAmount;

    component isKytCheckEnabled = OR();
    isKytCheckEnabled.a <== 1 - isZeroDeposit.out;
    isKytCheckEnabled.b <== 1 - isZeroWithdraw.out;

    component kytSignatureVerifier = EdDSAPoseidonVerifier();
    kytSignatureVerifier.enabled <== isKytCheckEnabled.out;
    kytSignatureVerifier.Ax <== kytEdDsaPubKey[0];
    kytSignatureVerifier.Ay <== kytEdDsaPubKey[1];
    kytSignatureVerifier.S <== kytSignature[0];
    kytSignatureVerifier.R8x <== kytSignature[1];
    kytSignatureVerifier.R8y <== kytSignature[2];

    assert(0 < nKytSignedMessage < 6);
    component kytSignedMessageHashInternal = Poseidon(nKytSignedMessage);
    for (var i = 0; i < nKytSignedMessage; i++) {
        kytSignedMessageHashInternal.inputs[i] <== kytSignedMessage[i];
    }
    kytSignatureVerifier.M <== kytSignedMessageHashInternal.out;

    component kytSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kytSignedMessageHashIsEqual.enabled <== isKytCheckEnabled.out;
    kytSignedMessageHashIsEqual.in[0] <== kytSignedMessageHash;
    kytSignedMessageHashIsEqual.in[1] <== kytSignedMessageHashInternal.out;

    // [13] - Verify kytEdDSA public key membership
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

    // [14] - Verify kyt leaf-id & rule allowed in zoneRecord - required if deposit or withdraw != 0
    component kytLeafIdAndRuleInclusionProver = KycKytMerkleTreeLeafIDAndRuleInclusionProver();
    component b2nLeafId = Bits2Num(KycKytMerkleTreeDepth);
    for (var j = 0; j < KycKytMerkleTreeDepth; j++) {
        b2nLeafId.in[j] <== kytPathIndex[j];
    }
    kytLeafIdAndRuleInclusionProver.enabled <== isKytCheckEnabled.out;
    kytLeafIdAndRuleInclusionProver.leafId <== b2nLeafId.out;
    kytLeafIdAndRuleInclusionProver.rule <== 0; // TODO: FIXME - extract rule from kytSignedMessage
    kytLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== zoneRecordKycKytMerkleTreeLeafIDsAndRulesList;
    kytLeafIdAndRuleInclusionProver.offset <== kytMerkleTreeLeafIDsAndRulesOffset;

    // [15] - Verify DataEscrow public key membership
    component dataEscrowInclusionProver = KycKytNoteInclusionProver(KycKytMerkleTreeDepth);
    dataEscrowInclusionProver.enabled <== 1; // enabled in any case
    dataEscrowInclusionProver.root <== kycKytMerkleRoot;
    dataEscrowInclusionProver.key[0] <== dataEscrowPubKey[0];
    dataEscrowInclusionProver.key[1] <== dataEscrowPubKey[1];
    dataEscrowInclusionProver.expiryTime <== dataEscrowPubKeyExpiryTime;

    for (var j = 0; j < KycKytMerkleTreeDepth; j++) {
        dataEscrowInclusionProver.pathIndex[j] <== dataEscrowPathIndex[j];
        dataEscrowInclusionProver.pathElements[j] <== dataEscrowPathElements[j];
    }

    // [16] - Data Escrow encryption
    // ------------- scalars-size --------------
    // 1) 3 x 64 (zAsset)
    // 2) 1 x 64 (zAccount)
    // 3) nUtxoIn x 64 amount
    // 4) nUtxoOut x 64 amount
    // 5) nUtxoIn x ( zones-ids - 32 bit )
    // 6) nUtxoOut x ( zones-ids - 32 bit )
    // ------------- ec-points-size -------------
    // 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)

    var dataEscrowScalarSize = 3+1+nUtxoIn+nUtxoOut+nUtxoIn+nUtxoOut;
    var dataEscrowPointSize = nUtxoOut;

    component dataEscrow = DataEscrowElGamalEncryption(dataEscrowScalarSize,dataEscrowPointSize);

    var dataEscrowEncryptedPoints = dataEscrowScalarSize + dataEscrowPointSize;

    dataEscrow.ephimeralRandom <== dataEscrowEphimeralRandom;
    dataEscrow.pubKey[0] <== dataEscrowPubKey[0];
    dataEscrow.pubKey[1] <== dataEscrowPubKey[1];

    // --------------- scalars -----------------
    component dataEscrowScalarsSerializer = DataEscrowSerializer(nUtxoIn,nUtxoOut);
    dataEscrowScalarsSerializer.zAsset <== privateZAsset;
    dataEscrowScalarsSerializer.zAccountId <== zAccountUtxoInId;

    for (var j = 0; j < nUtxoIn; j++) {
        dataEscrowScalarsSerializer.utxoInAmount[j] <== utxoInAmount[j];
        dataEscrowScalarsSerializer.utxoInOriginZoneId[j] <== utxoInOriginZoneId[j];
        dataEscrowScalarsSerializer.utxoInTargetZoneId[j] <== zAccountUtxoInZoneId;
    }

    for (var j = 0; j < nUtxoOut; j++) {
        dataEscrowScalarsSerializer.utxoOutAmount[j] <== utxoOutAmount[j];
        dataEscrowScalarsSerializer.utxoOutOriginZoneId[j] <== zAccountUtxoInZoneId;
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

    // [17] - DAO Data Escrow encryption
    var daoDataEscrowScalarSize = 1 + nUtxoIn + nUtxoOut;

    component daoDataEscrow = DataEscrowElGamalEncryptionScalar(daoDataEscrowScalarSize);

    var daoDataEscrowEncryptedPoints = daoDataEscrowScalarSize;

    daoDataEscrow.ephimeralRandom <== daoDataEscrowEphimeralRandom;
    daoDataEscrow.pubKey[0] <== daoDataEscrowPubKey[0];
    daoDataEscrow.pubKey[1] <== daoDataEscrowPubKey[1];

    component daoDataEscrowScalarsSerializer = DaoDataEscrowSerializer(nUtxoIn,nUtxoOut);

    daoDataEscrowScalarsSerializer.zAccountId <== zAccountUtxoInId;

    for (var j = 0; j < nUtxoIn; j++) {
        daoDataEscrowScalarsSerializer.utxoInOriginZoneId[j] <== utxoInOriginZoneId[j];
        daoDataEscrowScalarsSerializer.utxoInTargetZoneId[j] <== zAccountUtxoInZoneId;
    }

    for (var j = 0; j < nUtxoOut; j++) {
        daoDataEscrowScalarsSerializer.utxoOutOriginZoneId[j] <== zAccountUtxoInZoneId;
        daoDataEscrowScalarsSerializer.utxoOutTargetZoneId[j] <== utxoOutTargetZoneId[j];
    }

    for (var j = 0; j < daoDataEscrowScalarSize; j++) {
        daoDataEscrow.scalarMessage[j] <== daoDataEscrowScalarsSerializer.out[j];
    }

    // [18] - Verify zoneRecord membership
    component zoneRecordNoteHasher = ZoneRecordNoteHasher();
    zoneRecordNoteHasher.zoneId <== zAccountUtxoInZoneId;
    zoneRecordNoteHasher.ecDsaPubKeyHash <== zoneRecordEcDsaPubKeyHash;
    zoneRecordNoteHasher.edDsaPubKey[0] <== zoneRecordEdDsaPubKey[0];
    zoneRecordNoteHasher.edDsaPubKey[1] <== zoneRecordEdDsaPubKey[1];
    zoneRecordNoteHasher.originZonesList <== zoneRecordOriginZonesList;
    zoneRecordNoteHasher.targetZonesList <== zoneRecordTargetZonesList;
    zoneRecordNoteHasher.networkIDsBitMap <== zoneRecordNetworkIDsBitMap;
    zoneRecordNoteHasher.kycKytMerkleTreeLeafIDsAndRulesList <== zoneRecordKycKytMerkleTreeLeafIDsAndRulesList;
    zoneRecordNoteHasher.kycExpiryTime <== zoneRecordKycExpiryTime;
    zoneRecordNoteHasher.kytExpiryTime <== zoneRecordKytExpiryTime;
    zoneRecordNoteHasher.depositMaxAmount <== zoneRecordDepositMaxAmount;
    zoneRecordNoteHasher.withdrawMaxAmount <== zoneRecordWithrawMaxAmount;
    zoneRecordNoteHasher.internalMaxAmount <== zoneRecordInternalMaxAmount;

    component zoneRecordInclusionProver = ZoneRecordNoteInclusionProver(ZoneRecordsMerkleTreeDepth);
    zoneRecordInclusionProver.zoneRecordCommitment <== zoneRecordNoteHasher.out;
    zoneRecordInclusionProver.root <== zoneRecordMerkleRoot;
    for (var j=0; j < ZoneRecordsMerkleTreeDepth; j++) {
        zoneRecordInclusionProver.pathIndices[j] <== zoneRecordPathIndex[j];
        zoneRecordInclusionProver.pathElements[j] <== zoneRecordPathElements[j];
    }

    // [19] - Verify zoneRecord max external limits
    assert(zoneRecordDepositMaxAmount >= depositAmount);
    assert(zoneRecordWithrawMaxAmount >= withdrawAmount);

    // [20] - zAccountId data escrow for zone operator
    var zoneRecordDataEscrowScalarSize = 1;

    component zoneRecordDataEscrow = DataEscrowElGamalEncryptionScalar(zoneRecordDataEscrowScalarSize);

    var zoneRecordDataEscrowEncryptedPoints = zoneRecordDataEscrowScalarSize;

    zoneRecordDataEscrow.ephimeralRandom <== zoneRecordDataEscrowEphimeralRandom;
    zoneRecordDataEscrow.pubKey[0] <== zoneRecordEdDsaPubKey[0];
    zoneRecordDataEscrow.pubKey[1] <== zoneRecordEdDsaPubKey[1];
    zoneRecordDataEscrow.scalarMessage[0] <== zAccountUtxoInId;

    // [21] - Verify "public" input signals
    component publicInputHasher = PublicInputHasherExtended( nUtxoIn,
                                                             nUtxoOut,
                                                             zoneRecordDataEscrowEncryptedPoints,
                                                             dataEscrowEncryptedPoints,
                                                             daoDataEscrowEncryptedPoints );
    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.extraInputsHash <== extraInputsHash;
    publicInputHasher.publicZAsset <== publicZAsset;
    publicInputHasher.depositAmount <== depositAmount;
    publicInputHasher.withdrawAmount <== withdrawAmount;
    publicInputHasher.zAssetMerkleRoot <== zAssetMerkleRoot;
    publicInputHasher.forTxReward <== forTxReward;
    publicInputHasher.forUtxoReward <== forUtxoReward;
    publicInputHasher.forDepositReward <== forDepositReward;
    publicInputHasher.spendTime <== spendTime;

    // -------------------------------------------------------------------------------------------------------------- //
    for (var i = 0; i < nUtxoIn; i++) {
        publicInputHasher.utxoInMerkleRoot[i] <== utxoInMerkleRoot[i];
        publicInputHasher.utxoInTreeNumber[i] <== utxoInTreeNumber[i];
        publicInputHasher.utxoInNullifier[i] <== utxoInNullifierHasher[i].out;
    }

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.zAccountUtxoInMerkleRoot <== zAccountUtxoInMerkleRoot;
    publicInputHasher.zAccountUtxoInTreeNumber <== zAccountUtxoInTreeNumber;
    publicInputHasher.zAccountUtxoInNullifier <== zAccountUtxoInNullifierHasher.out;

    publicInputHasher.zAccountBlackListMerkleRoot <== zAccountBlackListMerkleRoot;

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.zoneRecordMerkleRoot <== zoneRecordMerkleRoot;

    publicInputHasher.zoneRecordDataEscrowEphimeralPubKey[0] <== zoneRecordDataEscrow.ephimeralPubKey[0];
    publicInputHasher.zoneRecordDataEscrowEphimeralPubKey[1] <== zoneRecordDataEscrow.ephimeralPubKey[1];

    for (var i = 0; i < zoneRecordDataEscrowEncryptedPoints; i++) {
        publicInputHasher.zoneRecordDataEscrowEncryptedMessage[i][0] <== zoneRecordDataEscrow.encryptedMessage[i][0];
        publicInputHasher.zoneRecordDataEscrowEncryptedMessage[i][1] <== zoneRecordDataEscrow.encryptedMessage[i][1];
    }

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.kytSignedMessageHash <== kytSignedMessageHash;
    publicInputHasher.kycKytMerkleRoot <== kycKytMerkleRoot;

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.dataEscrowEphimeralPubKey[0] <== dataEscrow.ephimeralPubKey[0];
    publicInputHasher.dataEscrowEphimeralPubKey[1] <== dataEscrow.ephimeralPubKey[1];

    for (var i = 0; i < dataEscrowEncryptedPoints; i++) {
        publicInputHasher.dataEscrowEncryptedMessage[i][0] <== dataEscrow.encryptedMessage[i][0];
        publicInputHasher.dataEscrowEncryptedMessage[i][1] <== dataEscrow.encryptedMessage[i][1];
    }

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.daoDataEscrowPubKey[0] <== daoDataEscrowPubKey[0];
    publicInputHasher.daoDataEscrowPubKey[1] <== daoDataEscrowPubKey[1];

    publicInputHasher.daoDataEscrowEphimeralPubKey[0] <== daoDataEscrow.ephimeralPubKey[0];
    publicInputHasher.daoDataEscrowEphimeralPubKey[1] <== daoDataEscrow.ephimeralPubKey[1];

    for (var i = 0; i < daoDataEscrowEncryptedPoints; i++) {
       publicInputHasher.daoDataEscrowEncryptedMessage[i][0] <== daoDataEscrow.encryptedMessage[i][0];
       publicInputHasher.daoDataEscrowEncryptedMessage[i][1] <== daoDataEscrow.encryptedMessage[i][1];
    }

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.utxoOutCreateTime <== utxoOutCreateTime;

    for (var i = 0; i < nUtxoOut; i++) {
        publicInputHasher.utxoOutOriginNetworkId[i] <== utxoOutOriginNetworkId[i];
        publicInputHasher.utxoOutCommitments[i] <== utxoOutNoteHasher[i].out;
    }

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.zAccountUtxoOutCommitment <== zAccountUtxoOutHasher.out;

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.chargedAmountZkp <== chargedAmountZkp;

    // -------------------------------------------------------------------------------------------------------------- //
    publicInputHasher.out === publicInputsHash;
}
