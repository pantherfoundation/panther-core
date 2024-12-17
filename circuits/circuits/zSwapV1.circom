//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

// project deps
include "./templates/balanceChecker.circom";
include "./templates/dataEscrowElGamalEncryption.circom";
include "./templates/trustProvidersKyt.circom";
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

// 3rd-party deps
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template ZSwapV1( nUtxoIn,
                  nUtxoOut,
                  UtxoLeftMerkleTreeDepth,
                  UtxoMiddleMerkleTreeDepth,
                  ZNetworkMerkleTreeDepth,
                  ZAssetMerkleTreeDepth,
                  ZAccountBlackListMerkleTreeDepth,
                  ZZoneMerkleTreeDepth,
                  TrustProvidersMerkleTreeDepth,
                  isSwap,
                  IsTestNet ) {
    //////////////////////////////////////////////////////////////////////////////////////////////
    // Ferry MT size
    var UtxoRightMerkleTreeDepth = UtxoRightMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // Equal to ferry MT size
    var UtxoMerkleTreeDepth = UtxoMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);
    // Bus MT extra levels
    var UtxoMiddleExtraLevels = UtxoMiddleExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, UtxoLeftMerkleTreeDepth);
    // Ferry MT extra levels
    var UtxoRightExtraLevels = UtxoRightExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth);

    // zSwap vs zTransaction variables
    var arraySizeInCaseOfSwap = TokenArraySize( isSwap );
    var transactedToken = TransactedTokenIndex();
    var swapToken = SwapTokenIndex();
    var zkpToken = ZkpTokenIndex( isSwap );
    var zAssetArraySize = ZAssetArraySize( isSwap ); // zkp token in last position

    // zZone data-escrow
    var zZoneDataEscrowEncryptedPoints = ZZoneDataEscrowEncryptedPoints_Fn();
    // main data-escrow
    var dataEscrowEncryptedPoints = DataEscrowEncryptedPoints_Fn( nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth );
    // dao data-escrow
    var daoDataEscrowEncryptedPoints = DaoDataEscrowEncryptedPoints_Fn();
    // misc
    var ACTIVE = Active();
    var NON_ACTIVE = NonActive();
    //////////////////////////////////////////////////////////////////////////////////////////////
    // external data anchoring
    signal input extraInputsHash;  // public

    // tx api
    signal input {uint96} depositAmount;    // public
    signal input {uint96} withdrawAmount;   // public
    signal input {uint96} addedAmountZkp;   // public

    signal input {uint168} token[arraySizeInCaseOfSwap];            // public - 168 bit ERC20 address - in case of internal tx will be zero
    signal input {uint252} tokenId[arraySizeInCaseOfSwap];          // public - 256 bit - in case of internal tx will be zero, in case of NTF it is NFT-ID
    signal input {uint64}  utxoZAsset[arraySizeInCaseOfSwap];       // used both for in & out utxo

    signal input {uint64}          zAssetId[zAssetArraySize];
    signal input {uint168}         zAssetToken[zAssetArraySize];
    signal input {uint252}         zAssetTokenId[zAssetArraySize];
    signal input {uint6}           zAssetNetwork[zAssetArraySize];
    signal input {uint32}          zAssetOffset[zAssetArraySize];
    signal input {uint48}          zAssetWeight[zAssetArraySize];
    signal input {non_zero_uint64} zAssetScale[zAssetArraySize];    // public - only in zSwap case
    signal input                   zAssetMerkleRoot;
    signal input {binary}          zAssetPathIndices[zAssetArraySize][ZAssetMerkleTreeDepth];
    signal input                   zAssetPathElements[zAssetArraySize][ZAssetMerkleTreeDepth];

    // reward computation params
    signal input {uint40} forTxReward;
    signal input {uint40} forUtxoReward;
    signal input {uint40} forDepositReward;

    signal input {uint32} spendTime; // public

    // input 'zAsset UTXOs'
    // to switch-off:
    //      1) utxoInAmount = 0
    //      2) utxoInSpendPrivKey = 0
    //      3) utxoInSpendKeyRandom = 0
    // switch-off control is used for:
    //      1) deposit only tx
    //      2) deposit & zAccount::zkpAmount
    //      3) deposit & zAccount::zkpAmount & withdraw
    //      4) deposit & withdraw
    signal input {sub_order_bj_sf} utxoInSpendPrivKey[nUtxoIn];
    signal input {sub_order_bj_sf} utxoInSpendKeyRandom[nUtxoIn];
    signal input {uint64}   utxoInAmount[nUtxoIn];
    signal input {uint16}   utxoInOriginZoneId[nUtxoIn];
    signal input {uint4}    utxoInOriginZoneIdOffset[nUtxoIn];
    signal input {uint6}    utxoInOriginNetworkId[nUtxoIn];
    signal input {uint6}    utxoInTargetNetworkId[nUtxoIn];
    signal input {uint32}   utxoInCreateTime[nUtxoIn];
    signal input {uint24}   utxoInZAccountId[nUtxoIn];
    signal input {binary}   utxoInMerkleTreeSelector[nUtxoIn][2]; // 2 bits: `00` - Taxi, `01` - Bus, `10` - Ferry
    signal input {binary}   utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth];
    signal input            utxoInPathElements[nUtxoIn][UtxoMerkleTreeDepth];
    signal input {external} utxoInNullifier[nUtxoIn]; // public
    signal input {sub_order_bj_p} utxoInDataEscrowPubKey[nUtxoIn][2];

    // input 'zAccount UTXO'
    signal input {uint24}          zAccountUtxoInId;
    signal input {uint64}          zAccountUtxoInZkpAmount;
    signal input {uint196}         zAccountUtxoInPrpAmount;
    signal input {uint16}          zAccountUtxoInZoneId;
    signal input {uint6}           zAccountUtxoInNetworkId;
    signal input {uint32}          zAccountUtxoInExpiryTime;
    signal input {uint32}          zAccountUtxoInNonce;
    signal input {uint96}          zAccountUtxoInTotalAmountPerTimePeriod;
    signal input {uint32}          zAccountUtxoInCreateTime;
    signal input {sub_order_bj_p}  zAccountUtxoInRootSpendPubKey[2];
    signal input {sub_order_bj_p}  zAccountUtxoInReadPubKey[2];
    signal input {sub_order_bj_p}  zAccountUtxoInNullifierPubKey[2];
    signal input {uint160}         zAccountUtxoInMasterEOA;
    signal input {sub_order_bj_sf} zAccountUtxoInSpendPrivKey;
    signal input {sub_order_bj_sf} zAccountUtxoInReadPrivKey;
    signal input {sub_order_bj_sf} zAccountUtxoInNullifierPrivKey;
    signal input {binary}          zAccountUtxoInMerkleTreeSelector[2]; // 2 bits: `00` - Taxi, `10` - Bus, `01` - Ferry
    signal input {binary}          zAccountUtxoInPathIndices[UtxoMerkleTreeDepth];
    signal input                   zAccountUtxoInPathElements[UtxoMerkleTreeDepth];
    signal input {external}        zAccountUtxoInNullifier; // public

    // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
    signal input zAccountBlackListLeaf;
    signal input zAccountBlackListMerkleRoot;
    signal input zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth];

    // zZone
    signal input {uint240}         zZoneOriginZoneIDs;
    signal input {uint240}         zZoneTargetZoneIDs;
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
    signal input {sub_order_bj_sf} zZoneDataEscrowEphemeralRandom;
    signal input                   zZoneDataEscrowEphemeralPubKeyAx; // public
    signal input                   zZoneDataEscrowEphemeralPubKeyAy;
    signal input {uint240}         zZoneZAccountIDsBlackList;
    signal input {uint96}          zZoneMaximumAmountPerTimePeriod;
    signal input {uint32}          zZoneTimePeriodPerMaximumAmount;
    signal input {binary}          zZoneSealing;

    signal input zZoneDataEscrowEncryptedMessage[zZoneDataEscrowEncryptedPoints]; // public
    signal input zZoneDataEscrowEncryptedMessageHmac; // public

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // Note: for swap case, kyt-hash = zero also can switch-off the KYT verification check
    // switch-off control is used for internal tx
    signal input {sub_order_bj_p} kytEdDsaPubKey[2];
    signal input {uint32}         kytEdDsaPubKeyExpiryTime;
    signal input                  trustProvidersMerkleRoot;                       // used both for kytSignature, DataEscrow, DaoDataEscrow
    signal input                  kytPathElements[TrustProvidersMerkleTreeDepth];
    signal input {binary}         kytPathIndices[TrustProvidersMerkleTreeDepth];
    signal input {uint4}          kytMerkleTreeLeafIDsAndRulesOffset;     // used for both cases of deposit & withdraw
    // deposit case
    signal input            kytDepositSignedMessagePackageType;
    signal input            kytDepositSignedMessageTimestamp;
    signal input            kytDepositSignedMessageSender;         // public
    signal input            kytDepositSignedMessageReceiver;       // public
    signal input {uint160}  kytDepositSignedMessageToken;
    signal input            kytDepositSignedMessageSessionId;
    signal input {uint8}    kytDepositSignedMessageRuleId;
    signal input {uint96}   kytDepositSignedMessageAmount;
    signal input {uint96}   kytDepositSignedMessageChargedAmountZkp;
    signal input {uint160}  kytDepositSignedMessageSigner;
    signal input            kytDepositSignedMessageHash;                // public
    signal input            kytDepositSignature[3];                     // S,R8x,R8y
    // withdraw case
    signal input            kytWithdrawSignedMessagePackageType;
    signal input            kytWithdrawSignedMessageTimestamp;
    signal input            kytWithdrawSignedMessageSender;            // public
    signal input            kytWithdrawSignedMessageReceiver;          // public
    signal input {uint160}  kytWithdrawSignedMessageToken;
    signal input            kytWithdrawSignedMessageSessionId;
    signal input {uint8}    kytWithdrawSignedMessageRuleId;
    signal input {uint96}   kytWithdrawSignedMessageAmount;
    signal input {uint96}   kytWithdrawSignedMessageChargedAmountZkp;
    signal input {uint160}  kytWithdrawSignedMessageSigner;
    signal input            kytWithdrawSignedMessageHash;                // public
    signal input            kytWithdrawSignature[3];                     // S,R8x,R8y
    // internal case
    signal input            kytSignedMessagePackageType;
    signal input            kytSignedMessageTimestamp;
    signal input            kytSignedMessageSessionId;
    signal input {uint96}   kytSignedMessageChargedAmountZkp;
    signal input {uint160}  kytSignedMessageSigner;
    signal input            kytSignedMessageDataEscrowHash;      // of data-escrow encrypted points
    signal input            kytSignedMessageHash;                // public - Hash( 6-signed-message-params )
    signal input            kytSignature[3];                     // S,R8x,R8y

    // data escrow
    signal input {sub_order_bj_p}  dataEscrowPubKey[2];
    signal input {uint32}          dataEscrowPubKeyExpiryTime;
    signal input {sub_order_bj_sf} dataEscrowEphemeralRandom;
    signal input                   dataEscrowEphemeralPubKeyAx;
    signal input                   dataEscrowEphemeralPubKeyAy;
    signal input                   dataEscrowPathElements[TrustProvidersMerkleTreeDepth];
    signal input {binary}          dataEscrowPathIndices[TrustProvidersMerkleTreeDepth];

    signal input dataEscrowEncryptedMessage[dataEscrowEncryptedPoints]; // public
    signal input dataEscrowEncryptedMessageHmac; // public

    // dao data escrow
    signal input {sub_order_bj_p}  daoDataEscrowPubKey[2];
    signal input {sub_order_bj_sf} daoDataEscrowEphemeralRandom;
    signal input                   daoDataEscrowEphemeralPubKeyAx; // public
    signal input                   daoDataEscrowEphemeralPubKeyAy;

    signal input daoDataEscrowEncryptedMessage[daoDataEscrowEncryptedPoints]; // public
    signal input daoDataEscrowEncryptedMessageHmac; // public

    // output 'zAsset UTXOs'
    // to switch-off:
    //      1) utxoOutAmount = 0
    // switch-off control is used for
    //      1) withdraw only tx
    //      2) zAccount::zkpAmount & withdraw
    //      3) deposit & zAccount::zkpAmount & withdraw
    //      4) deposit & withdraw
    signal input {uint32}          utxoOutCreateTime;                // public
    signal input {uint64}          utxoOutAmount[nUtxoOut];          // in zAsset units
    signal input {uint6}           utxoOutOriginNetworkId[nUtxoOut];
    signal input {uint6}           utxoOutTargetNetworkId[nUtxoOut];
    signal input {uint16}          utxoOutTargetZoneId[nUtxoOut];
    signal input {uint4}           utxoOutTargetZoneIdOffset[nUtxoOut];
    signal input {sub_order_bj_sf} utxoOutSpendPubKeyRandom[nUtxoOut];
    signal input {sub_order_bj_p}  utxoOutRootSpendPubKey[nUtxoOut][2];
    signal input                   utxoOutCommitment[nUtxoOut]; // public

    // output 'zAccount UTXO'
    signal input {uint64}          zAccountUtxoOutZkpAmount;
    signal input {sub_order_bj_sf} zAccountUtxoOutSpendKeyRandom;
    signal input                   zAccountUtxoOutCommitment; // public

    // output 'protocol + relayer fee in ZKP'
    signal input {uint96} chargedAmountZkp; // public

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
    0 === 0 * extraInputsHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1] - Check zAsset
    component zAssetChecker[arraySizeInCaseOfSwap];
    for (var i = 0; i < arraySizeInCaseOfSwap; i++) {
        zAssetChecker[i] = ZAssetChecker();
        zAssetChecker[i].token <== token[i];
        zAssetChecker[i].tokenId <== tokenId[i];
        zAssetChecker[i].zAssetId <== zAssetId[i];
        zAssetChecker[i].zAssetToken <== zAssetToken[i];
        zAssetChecker[i].zAssetTokenId <== zAssetTokenId[i];
        zAssetChecker[i].zAssetOffset <== zAssetOffset[i];
        zAssetChecker[i].depositAmount <== depositAmount;
        zAssetChecker[i].withdrawAmount <== withdrawAmount;
        zAssetChecker[i].utxoZAssetId <== utxoZAsset[i];
    }
    // [1.1] - Check zAsset-ZKP - verify it is zkp-token
    zAssetId[zkpToken] === ZkpToken();

    // [2] - Check the overall balance of all inputs & outputs amounts
    var totalUtxoInAmountVar = 0; // in zAsset units
    for (var i = 0 ; i < nUtxoIn; i++){
        // accumulate total
        totalUtxoInAmountVar += utxoInAmount[i];
    }
    signal totalUtxoInAmount <== Uint70Tag(ACTIVE)(totalUtxoInAmountVar);

    var totalUtxoOutAmountVar = 0; // in zAsset units
    for (var i = 0; i < nUtxoOut; i++){
        // accumulate total
        totalUtxoOutAmountVar += utxoOutAmount[i];
    }
    signal totalUtxoOutAmount <== Uint70Tag(ACTIVE)(totalUtxoOutAmountVar);

    // verify deposit & withdraw change
    component totalBalanceChecker = BalanceChecker();
    totalBalanceChecker.isZkpToken <== zAssetChecker[transactedToken].isZkpToken;
    totalBalanceChecker.depositAmount <== depositAmount;
    totalBalanceChecker.withdrawAmount <== withdrawAmount;
    totalBalanceChecker.chargedAmountZkp <== chargedAmountZkp;
    totalBalanceChecker.addedAmountZkp <== addedAmountZkp;
    totalBalanceChecker.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    totalBalanceChecker.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    totalBalanceChecker.totalUtxoInAmount <== totalUtxoInAmount;
    totalBalanceChecker.totalUtxoOutAmount <== totalUtxoOutAmount;
    totalBalanceChecker.zAssetWeight <== zAssetWeight[transactedToken];
    totalBalanceChecker.zAssetScale <== zAssetScale[transactedToken];
    totalBalanceChecker.zAssetScaleZkp <== zAssetScale[zkpToken];
    totalBalanceChecker.kytDepositChargedAmountZkp <== kytDepositSignedMessageChargedAmountZkp;
    totalBalanceChecker.kycWithdrawOrKytChargedAmountZkp <== kytWithdrawSignedMessageChargedAmountZkp;
    totalBalanceChecker.kytInternalChargedAmountZkp <== kytSignedMessageChargedAmountZkp;

    // [3] - Verify zAsset's membership and decode its weight
    component zAssetNoteInclusionProver[arraySizeInCaseOfSwap];

    for (var i = 0; i < arraySizeInCaseOfSwap; i++) {
        zAssetNoteInclusionProver[i] = ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth);
        zAssetNoteInclusionProver[i].zAsset <== zAssetId[i];
        zAssetNoteInclusionProver[i].token <== zAssetToken[i];
        zAssetNoteInclusionProver[i].tokenId <== zAssetTokenId[i];
        zAssetNoteInclusionProver[i].network <== zAssetNetwork[i];
        zAssetNoteInclusionProver[i].offset <== zAssetOffset[i];
        zAssetNoteInclusionProver[i].weight <== zAssetWeight[i];
        zAssetNoteInclusionProver[i].scale <== zAssetScale[i];
        zAssetNoteInclusionProver[i].merkleRoot <== zAssetMerkleRoot;
        zAssetNoteInclusionProver[i].pathIndices <== zAssetPathIndices[i];
        zAssetNoteInclusionProver[i].pathElements <== zAssetPathElements[i];
        // verify zAsset::network is equal to the current networkId
        zAssetNetwork[i] === zNetworkId;
    }

    // [4] - Pass values for computing rewards
    component rewards = RewardsExtended(nUtxoIn);
    rewards.depositScaledAmount <== totalBalanceChecker.depositScaledAmount;
    rewards.forTxReward <== forTxReward;
    rewards.forUtxoReward <== forUtxoReward;
    rewards.forDepositReward <== forDepositReward;
    rewards.spendTime <== spendTime;
    rewards.assetWeight <== zAssetWeight[transactedToken];
    rewards.utxoInCreateTime <== utxoInCreateTime;
    rewards.utxoInAmount <== utxoInAmount;

    // [5] - Verify input notes, membership, compute total amount of input 'zAsset UTXOs'
    component utxoInNullifierHasher[nUtxoIn];
    component utxoInNullifierProver[nUtxoIn];
    component utxoInSpendPubKey[nUtxoIn];
    component utxoInSpendPubKeyVerifier[nUtxoIn];
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

        // derive spending pub key from root-spend-pub key (anchor to zAccount)
        utxoInSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoInSpendPubKeyDeriver[i].rootPubKey <== zAccountUtxoInRootSpendPubKey;
        utxoInSpendPubKeyDeriver[i].random <== utxoInSpendKeyRandom[i]; // random generated by sender

        // derive spending pub key
        utxoInSpendPubKey[i] = BabyPbk();
        utxoInSpendPubKey[i].in <== utxoInSpendPrivKey[i]; // rootPrivKey * random
        // verify sub-order - disabled since it was checked during utxo-creation
        utxoInSpendPubKeyVerifier[i] = BabyJubJubSubGroupPointTag(NON_ACTIVE);
        utxoInSpendPubKeyVerifier[i].in[0] <== utxoInSpendPubKey[i].Ax;
        utxoInSpendPubKeyVerifier[i].in[1] <== utxoInSpendPubKey[i].Ay;

        // verify equality - can be switched-off by zero value of utxoInSpendKeyRandom & utxoInSpendPrivKey
        utxoInSpendPubKey[i].Ax === utxoInSpendPubKeyDeriver[i].derivedPubKey[0];
        utxoInSpendPubKey[i].Ay === utxoInSpendPubKeyDeriver[i].derivedPubKey[1];

        // compute commitment
        utxoInNoteHashers[i] = UtxoNoteHasher(0);
        utxoInNoteHashers[i].spendPk <== utxoInSpendPubKeyVerifier[i].out;
        utxoInNoteHashers[i].random <== utxoInSpendKeyRandom[i];
        utxoInNoteHashers[i].zAsset <== utxoZAsset[transactedToken];
        utxoInNoteHashers[i].amount <== utxoInAmount[i];
        utxoInNoteHashers[i].originNetworkId <== utxoInOriginNetworkId[i];
        utxoInNoteHashers[i].targetNetworkId <== utxoInTargetNetworkId[i];
        utxoInNoteHashers[i].createTime <== utxoInCreateTime[i];
        utxoInNoteHashers[i].originZoneId <== utxoInOriginZoneId[i];
        utxoInNoteHashers[i].targetZoneId <== zAccountUtxoInZoneId; // ALWAYS will be ZoneId of current zAccount
        utxoInNoteHashers[i].zAccountId <== utxoInZAccountId[i]; // ALWAYS will be ZAccountId of the sender
        utxoInNoteHashers[i].dataEscrowPubKey <== utxoInDataEscrowPubKey[i];

        // is-zero amount check
        utxoInIsEnabled[i] = IsNotZero();
        utxoInIsEnabled[i].in <== utxoInAmount[i];

        // verify if origin zoneId is allowed in zZone
        utxoInOriginZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoInOriginZoneIdInclusionProver[i].zoneId <== utxoInOriginZoneId[i];
        utxoInOriginZoneIdInclusionProver[i].zoneIds <== zZoneOriginZoneIDs;
        utxoInOriginZoneIdInclusionProver[i].offset <== utxoInOriginZoneIdOffset[i];
        utxoInOriginZoneIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify origin networkId is allowed in zZone
        utxoInOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInOriginNetworkIdInclusionProver[i].networkId <== utxoInOriginNetworkId[i];
        utxoInOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;
        utxoInOriginNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify target networkId is allowed in zZone
        utxoInTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInTargetNetworkIdInclusionProver[i].networkId <== utxoInTargetNetworkId[i];
        utxoInTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;
        utxoInTargetNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify origin networkId is allowed in zNetwork (if this network accepts origin-network at all)
        utxoInZNetworkOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoInZNetworkOriginNetworkIdInclusionProver[i].networkId <== utxoInOriginNetworkId[i];
        utxoInZNetworkOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zNetworkIDsBitMap;
        utxoInZNetworkOriginNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify target networkId is equal to zNetworkId
        utxoInZNetworkTargetNetworkIdInclusionProver[i] = ForceEqualIfEnabled();
        utxoInZNetworkTargetNetworkIdInclusionProver[i].in[0] <== zNetworkId;
        utxoInZNetworkTargetNetworkIdInclusionProver[i].in[1] <== utxoInTargetNetworkId[i];
        utxoInZNetworkTargetNetworkIdInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify nullifier
        utxoInNullifierHasher[i] = NullifierHasherExtended();
        utxoInNullifierHasher[i].privKey <== zAccountUtxoInNullifierPrivKey;
        utxoInNullifierHasher[i].pubKey <== utxoInDataEscrowPubKey[i];
        utxoInNullifierHasher[i].leaf <== utxoInNoteHashers[i].out;

        utxoInNullifierProver[i] = ForceEqualIfEnabled();
        utxoInNullifierProver[i].in[0] <== utxoInNullifier[i];
        utxoInNullifierProver[i].in[1] <== utxoInNullifierHasher[i].out;
        // As 'utxoInNullifier' is a public signal it is used for nullifier check.
        utxoInNullifierProver[i].enabled <== utxoInNullifier[i];

        // verify Merkle proofs for input notes
        utxoInInclusionProver[i] = UtxoNoteInclusionProverBinarySelectable(UtxoLeftMerkleTreeDepth,UtxoMiddleExtraLevels,UtxoRightExtraLevels);
        utxoInInclusionProver[i].note <== utxoInNoteHashers[i].out; // leaf in MerkleTree
        utxoInInclusionProver[i].treeSelector <== utxoInMerkleTreeSelector[i];
        utxoInInclusionProver[i].pathElements <== utxoInPathElements[i];
        utxoInInclusionProver[i].pathIndices <== utxoInPathIndices[i];
        utxoInInclusionProver[i].root[0] <== taxiMerkleRoot;
        utxoInInclusionProver[i].root[1] <== busMerkleRoot;
        utxoInInclusionProver[i].root[2] <== ferryMerkleRoot;

        // switch-on membership if amount != 0, otherwise switch-off
        utxoInInclusionProver[i].enabled <== utxoInIsEnabled[i].out;

        // verify zone max internal limits, no need to RC amount since its checked via utxo-out
        assert(0 <= utxoInAmount[i] < 2**64);
        // utxoInAmount[i] * zAssetWeight[transactedToken] - no need to RC since `zAssetWeight` anchored via MT & `amount`
        assert(zZoneInternalMaxAmount >= (utxoInAmount[i] * zAssetWeight[transactedToken]));
        isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[i] = ForceLessEqThan(96);
        isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[i].in[0] <== utxoInAmount[i] * zAssetWeight[transactedToken];
        isLessThanEq_weightedUtxoInAmount_zZoneInternalMaxAmount[i].in[1] <== zZoneInternalMaxAmount;
    }

    // [6] - Verify output notes and compute total amount of output 'zAsset UTXOs'
    component utxoOutNoteHasher[nUtxoOut];
    component utxoOutCommitmentProver[nUtxoIn];
    component utxoOutSpendPubKeyDeriver[nUtxoOut];
    component utxoOutSpendPubKeySubOrderVerifier[nUtxoOut];
    component utxoOutOriginNetworkIdInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdInclusionProver[nUtxoOut];
    component utxoOutOriginNetworkIdZNetworkInclusionProver[nUtxoOut];
    component utxoOutTargetNetworkIdZNetworkInclusionProver[nUtxoOut];
    component utxoOutZoneIdInclusionProver[nUtxoOut];
    component utxoOutIsEnabled[nUtxoOut];
    component isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[nUtxoOut];

    for (var i = 0; i < nUtxoOut; i++){
        // derive spending pub key from root-spend-pub key (anchor to zAccount)
        utxoOutSpendPubKeyDeriver[i] = PubKeyDeriver();
        utxoOutSpendPubKeyDeriver[i].rootPubKey <== utxoOutRootSpendPubKey[i];
        utxoOutSpendPubKeyDeriver[i].random <== utxoOutSpendPubKeyRandom[i]; // random generated by sender
        // verify
        utxoOutSpendPubKeySubOrderVerifier[i] = BabyJubJubSubGroupPointTag(ACTIVE);
        utxoOutSpendPubKeySubOrderVerifier[i].in <== utxoOutSpendPubKeyDeriver[i].derivedPubKey;

        var isSwapUtxo = isSwap && (i == nUtxoOut - 1);

        // verify commitment
        utxoOutNoteHasher[i] = UtxoNoteHasher(isSwapUtxo);
        utxoOutNoteHasher[i].spendPk <== utxoOutSpendPubKeySubOrderVerifier[i].out;
        utxoOutNoteHasher[i].random <== utxoOutSpendPubKeyRandom[i];
        if  ( isSwapUtxo ) {
            utxoOutNoteHasher[i].zAsset <== utxoZAsset[swapToken];
            // require zero utxo-out amounts in case of swap
            utxoOutAmount[i] === 0;
        } else {
            utxoOutNoteHasher[i].zAsset <== utxoZAsset[transactedToken];
        }
        utxoOutNoteHasher[i].amount <== utxoOutAmount[i];
        utxoOutNoteHasher[i].originNetworkId <== utxoOutOriginNetworkId[i];
        utxoOutNoteHasher[i].targetNetworkId <== utxoOutTargetNetworkId[i];
        utxoOutNoteHasher[i].createTime <== utxoOutCreateTime;
        utxoOutNoteHasher[i].originZoneId <== zAccountUtxoInZoneId; // ALWAYS will be ZoneId of current zAccount
        utxoOutNoteHasher[i].targetZoneId <== utxoOutTargetZoneId[i];
        utxoOutNoteHasher[i].zAccountId <== zAccountUtxoInId; // ALWAYS will be ZAccountId of current zAccount
        utxoOutNoteHasher[i].dataEscrowPubKey <== dataEscrowPubKey;

        utxoOutCommitmentProver[i] = ForceEqualIfEnabled();
        utxoOutCommitmentProver[i].in[0] <== utxoOutCommitment[i];
        utxoOutCommitmentProver[i].in[1] <== utxoOutNoteHasher[i].out;
        utxoOutCommitmentProver[i].enabled <== utxoOutCommitment[i];

        // verify if target zoneId is allowed in zZone (originZoneId verified via zAccount)
        utxoOutZoneIdInclusionProver[i] = ZoneIdInclusionProver();
        utxoOutZoneIdInclusionProver[i].zoneId <== utxoOutTargetZoneId[i];
        utxoOutZoneIdInclusionProver[i].zoneIds <== zZoneTargetZoneIDs;
        utxoOutZoneIdInclusionProver[i].offset <== utxoOutTargetZoneIdOffset[i];
        utxoOutZoneIdInclusionProver[i].enabled <== utxoOutCommitment[i];

        // verify origin networkId is allowed in zZone
        utxoOutOriginNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutOriginNetworkIdInclusionProver[i].networkId <== utxoOutOriginNetworkId[i];
        utxoOutOriginNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;
        utxoOutOriginNetworkIdInclusionProver[i].enabled <== utxoOutCommitment[i];

        // verify target networkId is allowed in zZone
        utxoOutTargetNetworkIdInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdInclusionProver[i].networkIdsBitMap <== zZoneNetworkIDsBitMap;
        utxoOutTargetNetworkIdInclusionProver[i].enabled <== utxoOutCommitment[i];

        // verify origin networkId is allowed (same as zNetworkId) in zNetwork
        utxoOutOriginNetworkIdZNetworkInclusionProver[i] = ForceEqualIfEnabled();
        utxoOutOriginNetworkIdZNetworkInclusionProver[i].in[0] <== zNetworkId;
        utxoOutOriginNetworkIdZNetworkInclusionProver[i].in[1] <== utxoOutOriginNetworkId[i];
        utxoOutOriginNetworkIdZNetworkInclusionProver[i].enabled <== utxoOutCommitment[i];

        // verify target networkId is allowed in zNetwork
        utxoOutTargetNetworkIdZNetworkInclusionProver[i] = NetworkIdInclusionProver();
        utxoOutTargetNetworkIdZNetworkInclusionProver[i].networkId <== utxoOutTargetNetworkId[i];
        utxoOutTargetNetworkIdZNetworkInclusionProver[i].networkIdsBitMap <== zNetworkIDsBitMap;
        utxoOutTargetNetworkIdZNetworkInclusionProver[i].enabled <== utxoOutCommitment[i];

        // verify zone max internal limits
        isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i] = ForceLessEqThan(96);
        if ( isSwapUtxo ) {
            assert(zZoneInternalMaxAmount >= (utxoOutAmount[i] * zAssetWeight[swapToken]));
            isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i].in[0] <== utxoOutAmount[i] * zAssetWeight[swapToken];
        }
        else {
            assert(zZoneInternalMaxAmount >= (utxoOutAmount[i] * zAssetWeight[transactedToken]));
            isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i].in[0] <== utxoOutAmount[i] * zAssetWeight[transactedToken];
        }
        isLessThanEq_weightedUtxoOutAmount_zZoneInternalMaxAmount[i].in[1] <== zZoneInternalMaxAmount;

        // ensure output amounts ranges (real check took place in top module via uint64 tag)
        assert(0 <= utxoOutAmount[i] < 2**64);
    }

    // [7] - Verify zZone max amount per time period
    assert(utxoOutCreateTime >= zAccountUtxoInCreateTime);
    component isLessThanEq_zAccountUtxoInCreateTime_utxoOutCreateTime = ForceLessEqThan(32);
    isLessThanEq_zAccountUtxoInCreateTime_utxoOutCreateTime.in[0] <== zAccountUtxoInCreateTime;
    isLessThanEq_zAccountUtxoInCreateTime_utxoOutCreateTime.in[1] <== utxoOutCreateTime;

    signal deltaTime <== utxoOutCreateTime - zAccountUtxoInCreateTime;

    component isDeltaTimeLessEqThen = LessEqThan(32); // 1 if deltaTime <= zZoneTimePeriodPerMaximumAmount
    isDeltaTimeLessEqThen.in[0] <== deltaTime;
    isDeltaTimeLessEqThen.in[1] <== zZoneTimePeriodPerMaximumAmount;
    // current total amount + previous amount (conditioned by time period)
    signal zAccountUtxoOutTotalAmountPerTimePeriod <== Uint96Tag(ACTIVE)( totalBalanceChecker.totalWeighted + ( isDeltaTimeLessEqThen.out * zAccountUtxoInTotalAmountPerTimePeriod ));

    // verify
    assert(zAccountUtxoOutTotalAmountPerTimePeriod <= zZoneMaximumAmountPerTimePeriod);
    component isLessThanEq_zAccountUtxoOutTotalAmountPerTimePeriod_zZoneMaximumAmountPerTimePeriod = ForceLessEqThan(96);
    isLessThanEq_zAccountUtxoOutTotalAmountPerTimePeriod_zZoneMaximumAmountPerTimePeriod.in[0] <== zAccountUtxoOutTotalAmountPerTimePeriod;
    isLessThanEq_zAccountUtxoOutTotalAmountPerTimePeriod_zZoneMaximumAmountPerTimePeriod.in[1] <== zZoneMaximumAmountPerTimePeriod;

    // [8] - Verify input 'zAccount UTXO input'
    component zAccountUtxoInSpendPubKey = BabyPbk();
    zAccountUtxoInSpendPubKey.in <== zAccountUtxoInSpendPrivKey;
    // verify sub-order, non-active since priv-key verified
    component zAccountUtxoInSpendPubKeyVerify = BabyJubJubSubGroupPointTag(NON_ACTIVE);
    zAccountUtxoInSpendPubKeyVerify.in[0] <== zAccountUtxoInSpendPubKey.Ax;
    zAccountUtxoInSpendPubKeyVerify.in[1] <== zAccountUtxoInSpendPubKey.Ay;

    component zAccountUtxoInHasher = ZAccountNoteHasher();
    zAccountUtxoInHasher.spendPubKey <== zAccountUtxoInSpendPubKeyVerify.out;
    zAccountUtxoInHasher.rootSpendPubKey <== zAccountUtxoInRootSpendPubKey;
    zAccountUtxoInHasher.readPubKey <== zAccountUtxoInReadPubKey;
    zAccountUtxoInHasher.nullifierPubKey <== zAccountUtxoInNullifierPubKey;
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

    // verify zAccountIn expiryTime
    assert(zAccountUtxoInExpiryTime >= utxoOutCreateTime);
    component isLessThanEq_utxoOutCreateTime_zAccountUtxoInExpiryTime = ForceLessEqThan(32);
    isLessThanEq_utxoOutCreateTime_zAccountUtxoInExpiryTime.in[0] <== utxoOutCreateTime;
    isLessThanEq_utxoOutCreateTime_zAccountUtxoInExpiryTime.in[1] <== zAccountUtxoInExpiryTime;

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
    zAccountUtxoInNullifierHasherProver.enabled <== zAccountUtxoInNullifier;

    // verify reading key
    component zAccountReadPubKeyChecker = BabyPbk();
    zAccountReadPubKeyChecker.in <== zAccountUtxoInReadPrivKey;
    zAccountReadPubKeyChecker.Ax === zAccountUtxoInReadPubKey[0];
    zAccountReadPubKeyChecker.Ay === zAccountUtxoInReadPubKey[1];

    // [10] - Verify zAccountUtxoIn membership
    component zAccountUtxoInMerkleVerifier = MerkleTreeInclusionProofDoubleLeavesSelectable(UtxoLeftMerkleTreeDepth,UtxoMiddleExtraLevels,UtxoRightExtraLevels);
    zAccountUtxoInMerkleVerifier.leaf <== zAccountUtxoInHasher.out;
    zAccountUtxoInMerkleVerifier.pathIndices <== zAccountUtxoInPathIndices;
    zAccountUtxoInMerkleVerifier.pathElements <== zAccountUtxoInPathElements;

    // tree selector
    zAccountUtxoInMerkleVerifier.treeSelector <== zAccountUtxoInMerkleTreeSelector;

    // choose the root to return, based upon `treeSelector`
    component zAccountRootSelectorSwitch = Selector3();
    zAccountRootSelectorSwitch.sel <== zAccountUtxoInMerkleTreeSelector;
    zAccountRootSelectorSwitch.L <== taxiMerkleRoot;
    zAccountRootSelectorSwitch.M <== busMerkleRoot;
    zAccountRootSelectorSwitch.R <== ferryMerkleRoot;

    // verify computed root against provided one
    component isEqualZAccountMerkleRoot = ForceEqualIfEnabled();
    isEqualZAccountMerkleRoot.in[0] <== zAccountRootSelectorSwitch.out;
    isEqualZAccountMerkleRoot.in[1] <== zAccountUtxoInMerkleVerifier.root;
    isEqualZAccountMerkleRoot.enabled <== zAccountRootSelectorSwitch.out;

    // [11] - Verify zAccountUtxoOut spend-pub-key is indeed derivation of zAccountRootSpendKey
    component zAccountUtxoOutPubKeyDeriver = PubKeyDeriver();
    zAccountUtxoOutPubKeyDeriver.rootPubKey <== zAccountUtxoInRootSpendPubKey;
    zAccountUtxoOutPubKeyDeriver.random <== zAccountUtxoOutSpendKeyRandom;
    // verify sub-order, non-active since priv-key verified
    component zAccountUtxoOutPubKeyDeriverSubOrderVerify = BabyJubJubSubGroupPointTag(NON_ACTIVE);
    zAccountUtxoOutPubKeyDeriverSubOrderVerify.in <== zAccountUtxoOutPubKeyDeriver.derivedPubKey;

    // [12] - Verify zAccountUtxoOut commitment
    component zAccountUtxoOutHasher = ZAccountNoteHasher();
    zAccountUtxoOutHasher.spendPubKey <== zAccountUtxoOutPubKeyDeriverSubOrderVerify.out;
    zAccountUtxoOutHasher.rootSpendPubKey <== zAccountUtxoInRootSpendPubKey;
    zAccountUtxoOutHasher.readPubKey <== zAccountUtxoInReadPubKey;
    zAccountUtxoOutHasher.nullifierPubKey <== zAccountUtxoInNullifierPubKey;
    zAccountUtxoOutHasher.masterEOA <== zAccountUtxoInMasterEOA;
    zAccountUtxoOutHasher.id <== zAccountUtxoInId;
    zAccountUtxoOutHasher.amountZkp <== zAccountUtxoOutZkpAmount;
    zAccountUtxoOutHasher.amountPrp <== Uint196Tag(ACTIVE)(zAccountUtxoInPrpAmount + rewards.amountPrp);
    zAccountUtxoOutHasher.zoneId <== zAccountUtxoInZoneId;
    zAccountUtxoOutHasher.expiryTime <== zAccountUtxoInExpiryTime;
    zAccountUtxoOutHasher.nonce <== Uint32Tag(ACTIVE)(zAccountUtxoInNonce + 1);
    zAccountUtxoOutHasher.totalAmountPerTimePeriod <== zAccountUtxoOutTotalAmountPerTimePeriod;
    zAccountUtxoOutHasher.createTime <== utxoOutCreateTime;
    zAccountUtxoOutHasher.networkId <== zAccountUtxoInNetworkId;

    component zAccountUtxoOutHasherProver = ForceEqualIfEnabled();
    zAccountUtxoOutHasherProver.in[0] <== zAccountUtxoOutCommitment;
    zAccountUtxoOutHasherProver.in[1] <== zAccountUtxoOutHasher.out;
    zAccountUtxoOutHasherProver.enabled <== zAccountUtxoOutCommitment;

    // [13] - Verify zAccountId exclusion proof
    component zAccountBlackListInlcusionProver = ZAccountBlackListLeafInclusionProver(ZAccountBlackListMerkleTreeDepth);
    zAccountBlackListInlcusionProver.zAccountId <== zAccountUtxoInId;
    zAccountBlackListInlcusionProver.leaf <== zAccountBlackListLeaf;
    zAccountBlackListInlcusionProver.merkleRoot <== zAccountBlackListMerkleRoot;
    zAccountBlackListInlcusionProver.pathElements <== zAccountBlackListPathElements;

    // [14] - Verify DataEscrow public key membership
    component isDataEscrowInclusionProverEnabled = IsNotZero();
    isDataEscrowInclusionProverEnabled.in <== trustProvidersMerkleRoot;

    component dataEscrowInclusionProver = TrustProvidersNoteInclusionProver(TrustProvidersMerkleTreeDepth);
    dataEscrowInclusionProver.enabled <== isDataEscrowInclusionProverEnabled.out;
    dataEscrowInclusionProver.root <== trustProvidersMerkleRoot;
    dataEscrowInclusionProver.key <== dataEscrowPubKey;
    dataEscrowInclusionProver.expiryTime <== dataEscrowPubKeyExpiryTime;
    dataEscrowInclusionProver.pathIndices <== dataEscrowPathIndices;
    dataEscrowInclusionProver.pathElements <== dataEscrowPathElements;

    assert(dataEscrowPubKeyExpiryTime >= utxoOutCreateTime);
    component isLessThanEq_utxoOutCreateTime_dataEscrowPubKeyExpiryTime = ForceLessEqThan(32);
    isLessThanEq_utxoOutCreateTime_dataEscrowPubKeyExpiryTime.in[0] <== utxoOutCreateTime;
    isLessThanEq_utxoOutCreateTime_dataEscrowPubKeyExpiryTime.in[1] <== dataEscrowPubKeyExpiryTime;

    // [15] - Data Escrow encryption
    component dataEscrow = DataEscrow(nUtxoIn,nUtxoOut,UtxoMerkleTreeDepth);
    // data
    dataEscrow.zAssetId <== utxoZAsset[transactedToken];
    dataEscrow.zAccountId <== zAccountUtxoInId;
    dataEscrow.zAccountZoneId <== zAccountUtxoInZoneId;
    dataEscrow.zAccountNonce <== zAccountUtxoInNonce;
    dataEscrow.utxoInMerkleTreeSelector <== utxoInMerkleTreeSelector;
    dataEscrow.utxoInPathIndices <== utxoInPathIndices;
    dataEscrow.utxoInAmount <== utxoInAmount;
    dataEscrow.utxoOutAmount <== utxoOutAmount;
    dataEscrow.utxoInOriginZoneId <== utxoInOriginZoneId;
    dataEscrow.utxoOutTargetZoneId <== utxoOutTargetZoneId;
    dataEscrow.utxoOutRootSpendPubKey <== utxoOutRootSpendPubKey;
    // main data escrow
    dataEscrow.dataEscrowEphemeralRandom <== dataEscrowEphemeralRandom;
    dataEscrow.dataEscrowPubKey <== dataEscrowPubKey;
    dataEscrow.dataEscrowEphemeralPubKeyAx <== dataEscrowEphemeralPubKeyAx;
    dataEscrow.dataEscrowEphemeralPubKeyAy <== dataEscrowEphemeralPubKeyAy;
    dataEscrow.dataEscrowEncryptedMessage <== dataEscrowEncryptedMessage;
    dataEscrow.dataEscrowEncryptedMessageHmac <== dataEscrowEncryptedMessageHmac;
    // dao data escrow
    dataEscrow.daoDataEscrowEphemeralRandom <== daoDataEscrowEphemeralRandom;
    dataEscrow.daoDataEscrowPubKey <== daoDataEscrowPubKey;
    dataEscrow.daoDataEscrowEphemeralPubKeyAx <== daoDataEscrowEphemeralPubKeyAx;
    dataEscrow.daoDataEscrowEphemeralPubKeyAy <== daoDataEscrowEphemeralPubKeyAy;
    dataEscrow.daoDataEscrowEncryptedMessage <== daoDataEscrowEncryptedMessage;
    dataEscrow.daoDataEscrowEncryptedMessageHmac <== daoDataEscrowEncryptedMessageHmac;
    // zZone data escrow
    dataEscrow.zZoneDataEscrowEphemeralRandom <== zZoneDataEscrowEphemeralRandom;
    dataEscrow.zZoneDataEscrowPubKey <== zZoneEdDsaPubKey;
    dataEscrow.zZoneDataEscrowEphemeralPubKeyAx <== zZoneDataEscrowEphemeralPubKeyAx;
    dataEscrow.zZoneDataEscrowEphemeralPubKeyAy <== zZoneDataEscrowEphemeralPubKeyAy;
    dataEscrow.zZoneDataEscrowEncryptedMessage <== zZoneDataEscrowEncryptedMessage;
    dataEscrow.zZoneDataEscrowEncryptedMessageHmac <== zZoneDataEscrowEncryptedMessageHmac;

    // [16] - Verify KYT signature
    component trustProvidersKytRandomHash = Poseidon(1);
    trustProvidersKytRandomHash.inputs[0] <== zAccountUtxoOutSpendKeyRandom;

    component trustProvidersKyt = TrustProvidersKyt(isSwap,TrustProvidersMerkleTreeDepth, IsTestNet);
    trustProvidersKyt.kytRandom <== trustProvidersKytRandomHash.out;
    trustProvidersKyt.kytToken <== token[transactedToken];
    trustProvidersKyt.kytDepositAmount <== depositAmount;
    trustProvidersKyt.kytWithdrawAmount <== withdrawAmount;
    trustProvidersKyt.kytMasterEOA <== zAccountUtxoInMasterEOA;
    trustProvidersKyt.kytSealing <== zZoneSealing;

    trustProvidersKyt.kytEdDsaPubKey <== kytEdDsaPubKey;
    trustProvidersKyt.kytEdDsaPubKeyExpiryTime <== kytEdDsaPubKeyExpiryTime;
    trustProvidersKyt.createTime <== utxoOutCreateTime;
    trustProvidersKyt.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    trustProvidersKyt.trustProvidersMerkleRoot <== trustProvidersMerkleRoot;
    trustProvidersKyt.kytPathElements <== kytPathElements;
    trustProvidersKyt.kytPathIndices <== kytPathIndices;
    trustProvidersKyt.kytTrustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    trustProvidersKyt.kytMerkleTreeLeafIDsAndRulesOffset <== kytMerkleTreeLeafIDsAndRulesOffset;
    // deposit
    trustProvidersKyt.kytDepositSignedMessagePackageType <== kytDepositSignedMessagePackageType;
    trustProvidersKyt.kytDepositSignedMessageTimestamp <== kytDepositSignedMessageTimestamp;
    trustProvidersKyt.kytDepositSignedMessageSender <== kytDepositSignedMessageSender;
    trustProvidersKyt.kytDepositSignedMessageReceiver <== kytDepositSignedMessageReceiver;
    trustProvidersKyt.kytDepositSignedMessageToken <== kytDepositSignedMessageToken;
    trustProvidersKyt.kytDepositSignedMessageSessionId <== kytDepositSignedMessageSessionId;
    trustProvidersKyt.kytDepositSignedMessageRuleId <== kytDepositSignedMessageRuleId;
    trustProvidersKyt.kytDepositSignedMessageAmount <== kytDepositSignedMessageAmount;
    trustProvidersKyt.kytDepositSignedMessageChargedAmountZkp <== kytDepositSignedMessageChargedAmountZkp;
    trustProvidersKyt.kytDepositSignedMessageSigner <== kytDepositSignedMessageSigner;
    trustProvidersKyt.kytDepositSignedMessageHash <== kytDepositSignedMessageHash;
    trustProvidersKyt.kytDepositSignature <== kytDepositSignature;
    // withdraw
    trustProvidersKyt.kytWithdrawSignedMessagePackageType <== kytWithdrawSignedMessagePackageType;
    trustProvidersKyt.kytWithdrawSignedMessageTimestamp <== kytWithdrawSignedMessageTimestamp;
    trustProvidersKyt.kytWithdrawSignedMessageSender <== kytWithdrawSignedMessageSender;
    trustProvidersKyt.kytWithdrawSignedMessageReceiver <== kytWithdrawSignedMessageReceiver;
    trustProvidersKyt.kytWithdrawSignedMessageToken <== kytWithdrawSignedMessageToken;
    trustProvidersKyt.kytWithdrawSignedMessageSessionId <== kytWithdrawSignedMessageSessionId;
    trustProvidersKyt.kytWithdrawSignedMessageRuleId <== kytWithdrawSignedMessageRuleId;
    trustProvidersKyt.kytWithdrawSignedMessageAmount <== kytWithdrawSignedMessageAmount;
    trustProvidersKyt.kytWithdrawSignedMessageChargedAmountZkp <== kytWithdrawSignedMessageChargedAmountZkp;
    trustProvidersKyt.kytWithdrawSignedMessageSigner <== kytWithdrawSignedMessageSigner;
    trustProvidersKyt.kytWithdrawSignedMessageHash <== kytWithdrawSignedMessageHash;
    trustProvidersKyt.kytWithdrawSignature <== kytWithdrawSignature;
    // internal
    trustProvidersKyt.kytSignedMessagePackageType <== kytSignedMessagePackageType;
    trustProvidersKyt.kytSignedMessageTimestamp <== kytSignedMessageTimestamp;
    trustProvidersKyt.kytSignedMessageSessionId <== kytSignedMessageSessionId;
    trustProvidersKyt.kytSignedMessageChargedAmountZkp <== kytSignedMessageChargedAmountZkp;
    trustProvidersKyt.kytSignedMessageSigner <== kytSignedMessageSigner;
    trustProvidersKyt.kytSignedMessageDataEscrowHash <== kytSignedMessageDataEscrowHash;
    trustProvidersKyt.kytSignedMessageHash <== kytSignedMessageHash;
    trustProvidersKyt.kytSignature <== kytSignature;

    // verify computed vs provided
    component kytSignedMessageDataEscrowHashProver = ForceEqualIfEnabled();
    kytSignedMessageDataEscrowHashProver.in[0] <== kytSignedMessageDataEscrowHash;
    kytSignedMessageDataEscrowHashProver.in[1] <== dataEscrow.dataEscrowEncryptedMessageHash;
    kytSignedMessageDataEscrowHashProver.enabled <== kytSignedMessageDataEscrowHash;

    // [17] - Verify zZone membership
    component zZoneNoteHasher = ZZoneNoteHasher();
    zZoneNoteHasher.zoneId <== zAccountUtxoInZoneId;
    zZoneNoteHasher.edDsaPubKey <== zZoneEdDsaPubKey;
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
    zZoneNoteHasher.dataEscrowPubKey <== dataEscrowPubKey;
    zZoneNoteHasher.sealing <== zZoneSealing;

    component zZoneInclusionProver = ZZoneNoteInclusionProver(ZZoneMerkleTreeDepth);
    zZoneInclusionProver.zZoneCommitment <== zZoneNoteHasher.out;
    zZoneInclusionProver.root <== zZoneMerkleRoot;
    zZoneInclusionProver.pathIndices <== zZonePathIndices;
    zZoneInclusionProver.pathElements <== zZonePathElements;

    // [18] - Verify zZone max external limits
    assert(zZoneDepositMaxAmount >= totalBalanceChecker.depositWeightedScaledAmount);
    component isLessThanEq_depositWeightedScaledAmount_zZoneDepositMaxAmount = ForceLessEqThan(96);
    isLessThanEq_depositWeightedScaledAmount_zZoneDepositMaxAmount.in[0] <== totalBalanceChecker.depositWeightedScaledAmount;
    isLessThanEq_depositWeightedScaledAmount_zZoneDepositMaxAmount.in[1] <== zZoneDepositMaxAmount;

    assert(zZoneWithdrawMaxAmount >= totalBalanceChecker.withdrawWeightedScaledAmount);
    component isLessThanEq_withdrawWeightedScaledAmount_zZoneWithdrawMaxAmount = ForceLessEqThan(96);
    isLessThanEq_withdrawWeightedScaledAmount_zZoneWithdrawMaxAmount.in[0] <== totalBalanceChecker.withdrawWeightedScaledAmount;
    isLessThanEq_withdrawWeightedScaledAmount_zZoneWithdrawMaxAmount.in[1] <== zZoneWithdrawMaxAmount;

    // [19] - Verify zAccountId exclusion
    component zZoneZAccountBlackListExclusionProver = ZZoneZAccountBlackListExclusionProver();
    zZoneZAccountBlackListExclusionProver.zAccountId <== zAccountUtxoInId;
    zZoneZAccountBlackListExclusionProver.zAccountIDsBlackList <== zZoneZAccountIDsBlackList;

    // [20] - Verify zNetwork's membership and decode its weight
    component zNetworkNoteInclusionProver = ZNetworkNoteInclusionProver(ZNetworkMerkleTreeDepth);
    zNetworkNoteInclusionProver.active <== BinaryOne()(); // ALWAYS ACTIVE
    zNetworkNoteInclusionProver.networkId <== zNetworkId;
    zNetworkNoteInclusionProver.chainId <== zNetworkChainId;
    zNetworkNoteInclusionProver.networkIDsBitMap <== zNetworkIDsBitMap;
    zNetworkNoteInclusionProver.forTxReward <== forTxReward;
    zNetworkNoteInclusionProver.forUtxoReward <== forUtxoReward;
    zNetworkNoteInclusionProver.forDepositReward <== forDepositReward;
    zNetworkNoteInclusionProver.daoDataEscrowPubKey <== daoDataEscrowPubKey;
    zNetworkNoteInclusionProver.merkleRoot <== zNetworkTreeMerkleRoot;
    zNetworkNoteInclusionProver.pathIndices <== zNetworkTreePathIndices;
    zNetworkNoteInclusionProver.pathElements <== zNetworkTreePathElements;

    // [21] - Verify static-merkle-root
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

    // [22] - Verify forest-merkle-roots
    component forestTreeMerkleRootVerifier = Poseidon(3);
    forestTreeMerkleRootVerifier.inputs[0] <== taxiMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[1] <== busMerkleRoot;
    forestTreeMerkleRootVerifier.inputs[2] <== ferryMerkleRoot;

    // verify computed root against provided one
    component isEqualForestTreeMerkleRoot = ForceEqualIfEnabled();
    isEqualForestTreeMerkleRoot.in[0] <== forestTreeMerkleRootVerifier.out;
    isEqualForestTreeMerkleRoot.in[1] <== forestMerkleRoot;
    isEqualForestTreeMerkleRoot.enabled <== forestMerkleRoot;

    // [23] - Verify salt
    component saltVerify = Poseidon(1);
    saltVerify.inputs[0] <== salt;

    component isEqualSalt = ForceEqualIfEnabled();
    isEqualSalt.in[0] <== saltVerify.out;
    isEqualSalt.in[1] <== saltHash;
    isEqualSalt.enabled <== saltHash;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [24] - Magical Constraint check ///////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    magicalConstraint * 0 === 0;
}
