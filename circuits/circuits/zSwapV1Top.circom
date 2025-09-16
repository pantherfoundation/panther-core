// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./templates/utils.circom";
include "./zSwapV1.circom";

template ZSwapV1Top( nUtxoIn,
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
    var swapOutUtxo = SwapOutUtxoIndex( nUtxoOut );
    var zkpToken = ZkpTokenIndex( isSwap );
    var zAssetArraySize = ZAssetArraySize( isSwap ); // zkp token in last position

    // zZone data-escrow
    var zZoneDataEscrowEncryptedPoints = ZZoneDataEscrowEncryptedPoints_Fn();
    // main data-escrow
    var dataEscrowScalarSize = DataEscrowScalarSize_Fn( nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth );
    var dataEscrowPointSize = DataEscrowPointSize_Fn( nUtxoOut );
    var dataEscrowEncryptedPoints = DataEscrowEncryptedPoints_Fn( nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth );
    // dao data-escrow
    var daoDataEscrowEncryptedPoints = DaoDataEscrowEncryptedPoints_Fn();
    //////////////////////////////////////////////////////////////////////////////////////////////
    // external data anchoring
    signal input extraInputsHash;  // public

    // tx api
    signal input depositAmount;    // public
    signal input withdrawAmount;   // public
    signal input addedAmountZkp; // public

    signal input token[arraySizeInCaseOfSwap];            // public - 160 bit ERC20 address - in case of internal tx will be zero
    signal input tokenId[arraySizeInCaseOfSwap];          // public - 256 bit - in case of internal tx will be zero, in case of NTF it is NFT-ID
    signal input utxoZAsset[arraySizeInCaseOfSwap];       // used both for in & out utxo

    signal input zAssetId[zAssetArraySize];
    signal input zAssetToken[zAssetArraySize];
    signal input zAssetTokenId[zAssetArraySize];
    signal input zAssetNetwork[zAssetArraySize];
    signal input zAssetOffset[zAssetArraySize];
    signal input zAssetWeight[zAssetArraySize];
    signal input zAssetScale[zAssetArraySize];
    signal input zAssetMerkleRoot;
    signal input zAssetPathIndices[zAssetArraySize][ZAssetMerkleTreeDepth];
    signal input zAssetPathElements[zAssetArraySize][ZAssetMerkleTreeDepth];

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
    //      4) deposit & withdraw
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
    signal input zZoneWithdrawMaxAmount;
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

    signal input zZoneDataEscrowEncryptedMessage[zZoneDataEscrowEncryptedPoints]; // public
    signal input zZoneDataEscrowEncryptedMessageHmac; // public

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // Note: for swap case, kyt-hash = zero also can switch-off the KYT verification check
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
    signal input dataEscrowEphemeralPubKeyAx;
    signal input dataEscrowEphemeralPubKeyAy;
    signal input dataEscrowPathElements[TrustProvidersMerkleTreeDepth];
    signal input dataEscrowPathIndices[TrustProvidersMerkleTreeDepth];

    signal input dataEscrowEncryptedMessage[dataEscrowEncryptedPoints]; // public
    signal input dataEscrowEncryptedMessageHmac; // public

    // dao data escrow
    signal input daoDataEscrowPubKey[2];
    signal input daoDataEscrowEphemeralRandom;
    signal input daoDataEscrowEphemeralPubKeyAx; // public
    signal input daoDataEscrowEphemeralPubKeyAy;

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
    var IGNORE_PUBLIC = NonActive();
    var IGNORE_ANCHORED = NonActive();
    var IGNORE_CHECKED_IN_CIRCOMLIB = NonActive();
    var ACTIVE = Active();

    signal rc_extraInputsHash <== ExternalTag()(extraInputsHash);
    signal rc_depositAmount <== Uint96Tag(IGNORE_PUBLIC)(depositAmount);
    signal rc_withdrawAmount <== Uint96Tag(IGNORE_PUBLIC)(withdrawAmount);
    signal rc_addedAmountZkp <== Uint96Tag(IGNORE_PUBLIC)(addedAmountZkp);
    signal rc_token[arraySizeInCaseOfSwap] <== Uint168TagArray(IGNORE_PUBLIC,arraySizeInCaseOfSwap)(token);
    signal rc_tokenId[arraySizeInCaseOfSwap] <== Uint252TagArray(IGNORE_PUBLIC,arraySizeInCaseOfSwap)(tokenId);
    signal rc_utxoZAsset[arraySizeInCaseOfSwap] <== Uint64TagArray(ACTIVE, arraySizeInCaseOfSwap)(utxoZAsset);

    signal rc_zAssetId[zAssetArraySize] <== Uint64TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetId);
    signal rc_zAssetToken[zAssetArraySize] <== Uint168TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetToken);
    signal rc_zAssetTokenId[zAssetArraySize] <== Uint252TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetTokenId);
    signal rc_zAssetNetwork[zAssetArraySize] <== Uint6TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetNetwork);
    signal rc_zAssetOffset[zAssetArraySize] <== Uint32TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetOffset);
    signal rc_zAssetWeight[zAssetArraySize] <== Uint48TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetWeight);
    signal rc_zAssetScale[zAssetArraySize] <== NonZeroUint64TagArray(IGNORE_ANCHORED,zAssetArraySize)(zAssetScale);
    signal rc_zAssetMerkleRoot <== SnarkFieldTag()(zAssetMerkleRoot);
    signal rc_zAssetPathIndices[zAssetArraySize][ZAssetMerkleTreeDepth] <== BinaryTag2DimArray(ACTIVE, zAssetArraySize,ZAssetMerkleTreeDepth)(zAssetPathIndices);
    signal rc_zAssetPathElements[zAssetArraySize][ZAssetMerkleTreeDepth] <== SnarkFieldTag2DimArray(zAssetArraySize,ZAssetMerkleTreeDepth)(zAssetPathElements);

    signal rc_forTxReward <== Uint40Tag(IGNORE_ANCHORED)(forTxReward);
    signal rc_forUtxoReward <== Uint40Tag(IGNORE_ANCHORED)(forUtxoReward);
    signal rc_forDepositReward <== Uint40Tag(IGNORE_ANCHORED)(forDepositReward);
    signal rc_spendTime <== Uint32Tag(IGNORE_PUBLIC)(spendTime);

    signal rc_utxoInSpendPrivKey[nUtxoIn] <== BabyJubJubSubOrderTagArray(ACTIVE,nUtxoIn)(utxoInSpendPrivKey);
    signal rc_utxoInSpendKeyRandom[nUtxoIn] <== BabyJubJubSubOrderTagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInSpendKeyRandom);
    signal rc_utxoInAmount[nUtxoIn] <== Uint64TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInAmount);
    signal rc_utxoInOriginZoneId[nUtxoIn] <== Uint16TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInOriginZoneId);
    signal rc_utxoInOriginZoneIdOffset[nUtxoIn] <== Uint4TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInOriginZoneIdOffset);
    signal rc_utxoInOriginNetworkId[nUtxoIn] <== Uint6TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInOriginNetworkId);
    signal rc_utxoInTargetNetworkId[nUtxoIn] <== Uint6TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInTargetNetworkId);
    signal rc_utxoInCreateTime[nUtxoIn] <==  Uint32TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInCreateTime);
    signal rc_utxoInZAccountId[nUtxoIn] <== Uint24TagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInZAccountId);
    signal rc_utxoInMerkleTreeSelector[nUtxoIn][2] <== BinaryTag2DimArray(ACTIVE,nUtxoIn,2)(utxoInMerkleTreeSelector);
    signal rc_utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth] <== BinaryTag2DimArray(ACTIVE,nUtxoIn,UtxoMerkleTreeDepth)(utxoInPathIndices);
    signal rc_utxoInPathElements[nUtxoIn][UtxoMerkleTreeDepth] <== SnarkFieldTag2DimArray(nUtxoIn,UtxoMerkleTreeDepth)(utxoInPathElements);
    signal rc_utxoInNullifier[nUtxoIn] <== ExternalTagArray(nUtxoIn)(utxoInNullifier);
    signal rc_utxoInDataEscrowPubKey[nUtxoIn][2] <== BabyJubJubSubGroupPointTagArray(IGNORE_ANCHORED,nUtxoIn)(utxoInDataEscrowPubKey);

    signal rc_zAccountUtxoInId <== Uint24Tag(ACTIVE)(zAccountUtxoInId);
    signal rc_zAccountUtxoInZkpAmount <== Uint64Tag(ACTIVE)(zAccountUtxoInZkpAmount);
    signal rc_zAccountUtxoInPrpAmount <== Uint196Tag(ACTIVE)(zAccountUtxoInPrpAmount);
    signal rc_zAccountUtxoInZoneId <== Uint16Tag(ACTIVE)(zAccountUtxoInZoneId);
    signal rc_zAccountUtxoInNetworkId <== Uint6Tag(ACTIVE)(zAccountUtxoInNetworkId);
    signal rc_zAccountUtxoInExpiryTime <== Uint32Tag(ACTIVE)(zAccountUtxoInExpiryTime);
    signal rc_zAccountUtxoInNonce <== Uint32Tag(ACTIVE)(zAccountUtxoInNonce);
    signal rc_zAccountUtxoInTotalAmountPerTimePeriod <== Uint96Tag(ACTIVE)(zAccountUtxoInTotalAmountPerTimePeriod);
    signal rc_zAccountUtxoInCreateTime <== Uint32Tag(ACTIVE)(zAccountUtxoInCreateTime);
    signal rc_zAccountUtxoInRootSpendPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(zAccountUtxoInRootSpendPubKey);
    signal rc_zAccountUtxoInReadPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(zAccountUtxoInReadPubKey);
    signal rc_zAccountUtxoInNullifierPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(zAccountUtxoInNullifierPubKey);
    signal rc_zAccountUtxoInMasterEOA <== Uint160Tag(IGNORE_ANCHORED)(zAccountUtxoInMasterEOA);
    signal rc_zAccountUtxoInSpendPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInSpendPrivKey);
    signal rc_zAccountUtxoInReadPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInReadPrivKey);
    signal rc_zAccountUtxoInNullifierPrivKey <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoInNullifierPrivKey);
    signal rc_zAccountUtxoInMerkleTreeSelector[2] <== BinaryTagArray(ACTIVE,2)(zAccountUtxoInMerkleTreeSelector);
    signal rc_zAccountUtxoInPathIndices[UtxoMerkleTreeDepth] <== BinaryTagArray(ACTIVE,UtxoMerkleTreeDepth)(zAccountUtxoInPathIndices);
    signal rc_zAccountUtxoInPathElements[UtxoMerkleTreeDepth] <== SnarkFieldTagArray(UtxoMerkleTreeDepth)(zAccountUtxoInPathElements);
    signal rc_zAccountUtxoInNullifier <== ExternalTag()(zAccountUtxoInNullifier);

    signal rc_zAccountBlackListLeaf <== SnarkFieldTag()(zAccountBlackListLeaf);
    signal rc_zAccountBlackListMerkleRoot <== SnarkFieldTag()(zAccountBlackListMerkleRoot);
    signal rc_zAccountBlackListPathElements[ZAccountBlackListMerkleTreeDepth] <== SnarkFieldTagArray(ZAccountBlackListMerkleTreeDepth)(zAccountBlackListPathElements);

    signal rc_zZoneOriginZoneIDs <== Uint240Tag(IGNORE_ANCHORED)(zZoneOriginZoneIDs);
    signal rc_zZoneTargetZoneIDs <== Uint240Tag(IGNORE_ANCHORED)(zZoneTargetZoneIDs);
    signal rc_zZoneNetworkIDsBitMap <== Uint64Tag(IGNORE_ANCHORED)(zZoneNetworkIDsBitMap);
    signal rc_zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== Uint240Tag(ACTIVE)(zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList);
    signal rc_zZoneKycExpiryTime <== Uint32Tag(IGNORE_ANCHORED)(zZoneKycExpiryTime);
    signal rc_zZoneKytExpiryTime <== Uint32Tag(IGNORE_ANCHORED)(zZoneKytExpiryTime);
    signal rc_zZoneDepositMaxAmount <== Uint96Tag(IGNORE_ANCHORED)(zZoneDepositMaxAmount);
    signal rc_zZoneWithdrawMaxAmount <== Uint96Tag(IGNORE_ANCHORED)(zZoneWithdrawMaxAmount);
    signal rc_zZoneInternalMaxAmount <== Uint96Tag(IGNORE_ANCHORED)(zZoneInternalMaxAmount);
    signal rc_zZoneMerkleRoot <== SnarkFieldTag()(zZoneMerkleRoot);
    signal rc_zZonePathElements[ZZoneMerkleTreeDepth] <== SnarkFieldTagArray(ZZoneMerkleTreeDepth)(zZonePathElements);
    signal rc_zZonePathIndices[ZZoneMerkleTreeDepth] <== BinaryTagArray(ACTIVE,ZZoneMerkleTreeDepth)(zZonePathIndices);
    signal rc_zZoneEdDsaPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(zZoneEdDsaPubKey);
    signal rc_zZoneDataEscrowEphemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(zZoneDataEscrowEphemeralRandom);

    component rc_zZoneDataEscrowEphemeralPubKey = BabyJubJubSubGroupPointTag(IGNORE_ANCHORED);
    rc_zZoneDataEscrowEphemeralPubKey.in[0] <== zZoneDataEscrowEphemeralPubKeyAx;
    rc_zZoneDataEscrowEphemeralPubKey.in[1] <== zZoneDataEscrowEphemeralPubKeyAy;
    signal rc_zZoneDataEscrowEphemeralPubKeyAx <== rc_zZoneDataEscrowEphemeralPubKey.out[0];
    signal rc_zZoneDataEscrowEphemeralPubKeyAy <==  rc_zZoneDataEscrowEphemeralPubKey.out[1];

    signal rc_zZoneZAccountIDsBlackList <== Uint240Tag(IGNORE_ANCHORED)(zZoneZAccountIDsBlackList);
    signal rc_zZoneMaximumAmountPerTimePeriod <== Uint96Tag(IGNORE_ANCHORED)(zZoneMaximumAmountPerTimePeriod);
    signal rc_zZoneTimePeriodPerMaximumAmount <== Uint32Tag(IGNORE_ANCHORED)(zZoneTimePeriodPerMaximumAmount);
    signal rc_zZoneSealing <== BinaryTag(IGNORE_ANCHORED)(zZoneSealing);
    signal rc_zZoneDataEscrowEncryptedMessage[zZoneDataEscrowEncryptedPoints] <== SnarkFieldTagArray(zZoneDataEscrowEncryptedPoints)(zZoneDataEscrowEncryptedMessage);
    signal rc_zZoneDataEscrowEncryptedMessageHmac <== ExternalTag()(zZoneDataEscrowEncryptedMessageHmac);

    signal rc_kytEdDsaPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(kytEdDsaPubKey);
    signal rc_kytEdDsaPubKeyExpiryTime <== Uint32Tag(ACTIVE)(kytEdDsaPubKeyExpiryTime);
    signal rc_trustProvidersMerkleRoot <== SnarkFieldTag()(trustProvidersMerkleRoot);

    signal rc_kytPathElements[TrustProvidersMerkleTreeDepth] <== SnarkFieldTagArray(TrustProvidersMerkleTreeDepth)(kytPathElements);
    signal rc_kytPathIndices[TrustProvidersMerkleTreeDepth] <== BinaryTagArray(ACTIVE,TrustProvidersMerkleTreeDepth)(kytPathIndices);
    signal rc_kytMerkleTreeLeafIDsAndRulesOffset <== Uint4Tag(ACTIVE)(kytMerkleTreeLeafIDsAndRulesOffset);
    signal rc_kytDepositSignedMessagePackageType <== IgnoreTag()(kytDepositSignedMessagePackageType);
    signal rc_kytDepositSignedMessageTimestamp <== IgnoreTag()(kytDepositSignedMessageTimestamp);
    signal rc_kytDepositSignedMessageSender <== ExternalTag()(kytDepositSignedMessageSender);
    signal rc_kytDepositSignedMessageReceiver <== ExternalTag()(kytDepositSignedMessageReceiver);
    signal rc_kytDepositSignedMessageToken <== Uint160Tag(ACTIVE)(kytDepositSignedMessageToken);
    signal rc_kytDepositSignedMessageSessionId <== IgnoreTag()(kytDepositSignedMessageSessionId);
    signal rc_kytDepositSignedMessageRuleId <== Uint8Tag(ACTIVE)(kytDepositSignedMessageRuleId);
    signal rc_kytDepositSignedMessageAmount <== Uint96Tag(ACTIVE)(kytDepositSignedMessageAmount);
    signal rc_kytDepositSignedMessageChargedAmountZkp <== Uint96Tag(ACTIVE)(kytDepositSignedMessageChargedAmountZkp);
    signal rc_kytDepositSignedMessageSigner <== Uint160Tag(ACTIVE)(kytDepositSignedMessageSigner);
    signal rc_kytDepositSignedMessageHash <== ExternalTag()(kytDepositSignedMessageHash);

    // Range checking for the signature components (R8 and S) are enforced in the EdDSAPoseidonVerifier() of circomlib itself.
    // Hence adding additional range checks for signature components (R8 and S) are redundant.
    signal rc_kytDepositSignature[3] <== kytDepositSignature;

    signal rc_kytWithdrawSignedMessagePackageType <== IgnoreTag()(kytWithdrawSignedMessagePackageType);
    signal rc_kytWithdrawSignedMessageTimestamp <== IgnoreTag()(kytWithdrawSignedMessageTimestamp);
    signal rc_kytWithdrawSignedMessageSender <== ExternalTag()(kytWithdrawSignedMessageSender);
    signal rc_kytWithdrawSignedMessageReceiver <== ExternalTag()(kytWithdrawSignedMessageReceiver);
    signal rc_kytWithdrawSignedMessageToken <== Uint160Tag(ACTIVE)(kytWithdrawSignedMessageToken);
    signal rc_kytWithdrawSignedMessageSessionId <== IgnoreTag()(kytWithdrawSignedMessageSessionId);
    signal rc_kytWithdrawSignedMessageRuleId <== Uint8Tag(ACTIVE)(kytWithdrawSignedMessageRuleId);
    signal rc_kytWithdrawSignedMessageAmount <== Uint96Tag(ACTIVE)(kytWithdrawSignedMessageAmount);
    signal rc_kytWithdrawSignedMessageChargedAmountZkp <== Uint96Tag(ACTIVE)(kytWithdrawSignedMessageChargedAmountZkp);
    signal rc_kytWithdrawSignedMessageSigner <== Uint160Tag(ACTIVE)(kytWithdrawSignedMessageSigner);
    signal rc_kytWithdrawSignedMessageHash <== ExternalTag()(kytWithdrawSignedMessageHash);

    // Range checking for the signature components (R8 and S) are enforced in the EdDSAPoseidonVerifier() of circomlib itself.
    // Hence adding additional range checks for signature components (R8 and S) are redundant.
    signal rc_kytWithdrawSignature[3] <== kytWithdrawSignature;

    signal rc_kytSignedMessagePackageType <== IgnoreTag()(kytSignedMessagePackageType);
    signal rc_kytSignedMessageTimestamp <== IgnoreTag()(kytSignedMessageTimestamp);
    signal rc_kytSignedMessageSessionId <== IgnoreTag()(kytSignedMessageSessionId);
    signal rc_kytSignedMessageChargedAmountZkp <== Uint96Tag(ACTIVE)(kytSignedMessageChargedAmountZkp);
    signal rc_kytSignedMessageSigner <== Uint160Tag(ACTIVE)(kytSignedMessageSigner);
    signal rc_kytSignedMessageDataEscrowHash <== SnarkFieldTag()(kytSignedMessageDataEscrowHash);
    signal rc_kytSignedMessageHash <== ExternalTag()(kytSignedMessageHash);

    // Range checking for the signature components (R8 and S) are enforced in the EdDSAPoseidonVerifier() of circomlib itself.
    // Hence adding additional range checks for signature components (R8 and S) are redundant.
    signal rc_kytSignature[3] <== kytSignature;

    signal rc_dataEscrowPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(dataEscrowPubKey);
    signal rc_dataEscrowPubKeyExpiryTime <== Uint32Tag(IGNORE_ANCHORED)(dataEscrowPubKeyExpiryTime);
    signal rc_dataEscrowEphemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(dataEscrowEphemeralRandom);
    signal rc_dataEscrowEphemeralPubKeyAx <== SnarkFieldTag()(dataEscrowEphemeralPubKeyAx);
    signal rc_dataEscrowEphemeralPubKeyAy <== SnarkFieldTag()(dataEscrowEphemeralPubKeyAy);
    signal rc_dataEscrowPathElements[TrustProvidersMerkleTreeDepth] <== SnarkFieldTagArray(TrustProvidersMerkleTreeDepth)(dataEscrowPathElements);
    signal rc_dataEscrowPathIndices[TrustProvidersMerkleTreeDepth] <== BinaryTagArray(ACTIVE,TrustProvidersMerkleTreeDepth)(dataEscrowPathIndices);
    signal rc_dataEscrowEncryptedMessage[dataEscrowEncryptedPoints] <== ExternalTagArray(dataEscrowEncryptedPoints)(dataEscrowEncryptedMessage);
    signal rc_dataEscrowEncryptedMessageHmac <== ExternalTag()(dataEscrowEncryptedMessageHmac);

    signal rc_daoDataEscrowPubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(daoDataEscrowPubKey);
    signal rc_daoDataEscrowEphemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(daoDataEscrowEphemeralRandom);
    signal rc_daoDataEscrowEphemeralPubKeyAx <== ExternalTag()(daoDataEscrowEphemeralPubKeyAx);
    signal rc_daoDataEscrowEphemeralPubKeyAy <== SnarkFieldTag()(daoDataEscrowEphemeralPubKeyAy);
    signal rc_daoDataEscrowEncryptedMessage[daoDataEscrowEncryptedPoints] <== ExternalTagArray(daoDataEscrowEncryptedPoints)(daoDataEscrowEncryptedMessage);
    signal rc_daoDataEscrowEncryptedMessageHmac <== ExternalTag()(daoDataEscrowEncryptedMessageHmac);

    signal rc_utxoOutCreateTime <== Uint32Tag(IGNORE_PUBLIC)(utxoOutCreateTime);
    signal rc_utxoOutAmount[nUtxoOut] <== Uint64TagArray(ACTIVE,nUtxoOut)(utxoOutAmount);
    signal rc_utxoOutOriginNetworkId[nUtxoOut] <== Uint6TagArray(ACTIVE,nUtxoOut)(utxoOutOriginNetworkId);
    signal rc_utxoOutTargetNetworkId[nUtxoOut] <== Uint6TagArray(ACTIVE,nUtxoOut)(utxoOutTargetNetworkId);
    signal rc_utxoOutTargetZoneId[nUtxoOut] <== Uint16TagArray(ACTIVE,nUtxoOut)(utxoOutTargetZoneId);
    signal rc_utxoOutTargetZoneIdOffset[nUtxoOut] <== Uint4TagArray(ACTIVE,nUtxoOut)(utxoOutTargetZoneIdOffset);
    signal rc_utxoOutSpendPubKeyRandom[nUtxoOut] <== BabyJubJubSubOrderTagArray(ACTIVE,nUtxoOut)(utxoOutSpendPubKeyRandom);
    signal rc_utxoOutRootSpendPubKey[nUtxoOut][2] <== BabyJubJubSubGroupPointTagArray(ACTIVE,nUtxoOut)(utxoOutRootSpendPubKey);
    signal rc_utxoOutCommitment[nUtxoOut] <== ExternalTagArray(nUtxoOut)(utxoOutCommitment);

    signal rc_zAccountUtxoOutZkpAmount <== Uint64Tag(ACTIVE)(zAccountUtxoOutZkpAmount);
    signal rc_zAccountUtxoOutSpendKeyRandom <== BabyJubJubSubOrderTag(ACTIVE)(zAccountUtxoOutSpendKeyRandom);
    signal rc_zAccountUtxoOutCommitment <== SnarkFieldTag()(zAccountUtxoOutCommitment);
    signal rc_chargedAmountZkp <== Uint96Tag(IGNORE_PUBLIC)(chargedAmountZkp);

    signal rc_zNetworkId <== Uint6Tag(ACTIVE)(zNetworkId);
    signal rc_zNetworkChainId <== ExternalTag()(zNetworkChainId);
    signal rc_zNetworkIDsBitMap <== Uint64Tag(ACTIVE)(zNetworkIDsBitMap);
    signal rc_zNetworkTreeMerkleRoot <== SnarkFieldTag()(zNetworkTreeMerkleRoot);
    signal rc_zNetworkTreePathElements[ZNetworkMerkleTreeDepth] <== SnarkFieldTagArray(ZNetworkMerkleTreeDepth)(zNetworkTreePathElements);
    signal rc_zNetworkTreePathIndices[ZNetworkMerkleTreeDepth] <== BinaryTagArray(ACTIVE,ZNetworkMerkleTreeDepth)(zNetworkTreePathIndices);

    signal rc_staticTreeMerkleRoot <== ExternalTag()(staticTreeMerkleRoot);
    signal rc_forestMerkleRoot <== ExternalTag()(forestMerkleRoot);
    signal rc_taxiMerkleRoot <== SnarkFieldTag()(taxiMerkleRoot);
    signal rc_busMerkleRoot <== SnarkFieldTag()(busMerkleRoot);
    signal rc_ferryMerkleRoot <== SnarkFieldTag()(ferryMerkleRoot);
    signal rc_salt <== SnarkFieldTag()(salt);
    signal rc_saltHash <== ExternalTag()(saltHash);
    signal rc_magicalConstraint <== ExternalTag()(magicalConstraint);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [-] - Logic ///////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component zSwapV1 = ZSwapV1( nUtxoIn,
                                 nUtxoOut,
                                 UtxoLeftMerkleTreeDepth,
                                 UtxoMiddleMerkleTreeDepth,
                                 ZNetworkMerkleTreeDepth,
                                 ZAssetMerkleTreeDepth,
                                 ZAccountBlackListMerkleTreeDepth,
                                 ZZoneMerkleTreeDepth,
                                 TrustProvidersMerkleTreeDepth,
                                 isSwap,
                                 IsTestNet );

    zSwapV1.extraInputsHash <== rc_extraInputsHash;
    zSwapV1.depositAmount <== rc_depositAmount;
    zSwapV1.withdrawAmount <== rc_withdrawAmount;
    zSwapV1.addedAmountZkp <== rc_addedAmountZkp;
    zSwapV1.token <== rc_token;
    zSwapV1.tokenId <== rc_tokenId;
    zSwapV1.utxoZAsset <== rc_utxoZAsset;
    zSwapV1.zAssetId <== rc_zAssetId;
    zSwapV1.zAssetToken <== rc_zAssetToken;
    zSwapV1.zAssetTokenId <== rc_zAssetTokenId;
    zSwapV1.zAssetNetwork <== rc_zAssetNetwork;
    zSwapV1.zAssetOffset <== rc_zAssetOffset;
    zSwapV1.zAssetWeight <== rc_zAssetWeight;
    zSwapV1.zAssetScale <== rc_zAssetScale;
    zSwapV1.zAssetMerkleRoot <== rc_zAssetMerkleRoot;
    zSwapV1.zAssetPathIndices <== rc_zAssetPathIndices;
    zSwapV1.zAssetPathElements <== rc_zAssetPathElements;
    zSwapV1.forTxReward <== rc_forTxReward;
    zSwapV1.forUtxoReward <== rc_forUtxoReward;
    zSwapV1.forDepositReward <== rc_forDepositReward;
    zSwapV1.spendTime <== rc_spendTime;
    zSwapV1.utxoInSpendPrivKey <== rc_utxoInSpendPrivKey;
    zSwapV1.utxoInSpendKeyRandom <== rc_utxoInSpendKeyRandom;
    zSwapV1.utxoInAmount <== rc_utxoInAmount;
    zSwapV1.utxoInOriginZoneId <== rc_utxoInOriginZoneId;
    zSwapV1.utxoInOriginZoneIdOffset <== rc_utxoInOriginZoneIdOffset;
    zSwapV1.utxoInOriginNetworkId <== rc_utxoInOriginNetworkId;
    zSwapV1.utxoInTargetNetworkId <== rc_utxoInTargetNetworkId;
    zSwapV1.utxoInCreateTime <== rc_utxoInCreateTime;
    zSwapV1.utxoInZAccountId <== rc_utxoInZAccountId;
    zSwapV1.utxoInMerkleTreeSelector <== rc_utxoInMerkleTreeSelector;
    zSwapV1.utxoInPathIndices <== rc_utxoInPathIndices;
    zSwapV1.utxoInPathElements <== rc_utxoInPathElements;
    zSwapV1.utxoInNullifier <== rc_utxoInNullifier;
    zSwapV1.utxoInDataEscrowPubKey <== rc_utxoInDataEscrowPubKey;
    zSwapV1.zAccountUtxoInId <== rc_zAccountUtxoInId;
    zSwapV1.zAccountUtxoInZkpAmount <== rc_zAccountUtxoInZkpAmount;
    zSwapV1.zAccountUtxoInPrpAmount <== rc_zAccountUtxoInPrpAmount;
    zSwapV1.zAccountUtxoInZoneId <== rc_zAccountUtxoInZoneId;
    zSwapV1.zAccountUtxoInNetworkId <== rc_zAccountUtxoInNetworkId;
    zSwapV1.zAccountUtxoInExpiryTime <== rc_zAccountUtxoInExpiryTime;
    zSwapV1.zAccountUtxoInNonce <== rc_zAccountUtxoInNonce;
    zSwapV1.zAccountUtxoInTotalAmountPerTimePeriod <== rc_zAccountUtxoInTotalAmountPerTimePeriod;
    zSwapV1.zAccountUtxoInCreateTime <== rc_zAccountUtxoInCreateTime;
    zSwapV1.zAccountUtxoInRootSpendPubKey <== rc_zAccountUtxoInRootSpendPubKey;
    zSwapV1.zAccountUtxoInReadPubKey <== rc_zAccountUtxoInReadPubKey;
    zSwapV1.zAccountUtxoInNullifierPubKey <== rc_zAccountUtxoInNullifierPubKey;
    zSwapV1.zAccountUtxoInMasterEOA <== rc_zAccountUtxoInMasterEOA;
    zSwapV1.zAccountUtxoInSpendPrivKey <== rc_zAccountUtxoInSpendPrivKey;
    zSwapV1.zAccountUtxoInReadPrivKey <== rc_zAccountUtxoInReadPrivKey;
    zSwapV1.zAccountUtxoInNullifierPrivKey <== rc_zAccountUtxoInNullifierPrivKey;
    zSwapV1.zAccountUtxoInMerkleTreeSelector <== rc_zAccountUtxoInMerkleTreeSelector;
    zSwapV1.zAccountUtxoInPathIndices <== rc_zAccountUtxoInPathIndices;
    zSwapV1.zAccountUtxoInPathElements <== rc_zAccountUtxoInPathElements;
    zSwapV1.zAccountUtxoInNullifier <== rc_zAccountUtxoInNullifier;
    zSwapV1.zAccountBlackListLeaf <== rc_zAccountBlackListLeaf;
    zSwapV1.zAccountBlackListMerkleRoot <== rc_zAccountBlackListMerkleRoot;
    zSwapV1.zAccountBlackListPathElements <== rc_zAccountBlackListPathElements;
    zSwapV1.zZoneOriginZoneIDs <== rc_zZoneOriginZoneIDs;
    zSwapV1.zZoneTargetZoneIDs <== rc_zZoneTargetZoneIDs;
    zSwapV1.zZoneNetworkIDsBitMap <== rc_zZoneNetworkIDsBitMap;
    zSwapV1.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== rc_zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zSwapV1.zZoneKycExpiryTime <== rc_zZoneKycExpiryTime;
    zSwapV1.zZoneKytExpiryTime <== rc_zZoneKytExpiryTime;
    zSwapV1.zZoneDepositMaxAmount <== rc_zZoneDepositMaxAmount;
    zSwapV1.zZoneWithdrawMaxAmount <== rc_zZoneWithdrawMaxAmount;
    zSwapV1.zZoneInternalMaxAmount <== rc_zZoneInternalMaxAmount;
    zSwapV1.zZoneMerkleRoot <== rc_zZoneMerkleRoot;
    zSwapV1.zZonePathElements <== rc_zZonePathElements;
    zSwapV1.zZonePathIndices <== rc_zZonePathIndices;
    zSwapV1.zZoneEdDsaPubKey <== rc_zZoneEdDsaPubKey;
    zSwapV1.zZoneDataEscrowEphemeralRandom <== rc_zZoneDataEscrowEphemeralRandom;
    zSwapV1.zZoneDataEscrowEphemeralPubKeyAx <== rc_zZoneDataEscrowEphemeralPubKeyAx;
    zSwapV1.zZoneDataEscrowEphemeralPubKeyAy <== rc_zZoneDataEscrowEphemeralPubKeyAy;
    zSwapV1.zZoneZAccountIDsBlackList <== rc_zZoneZAccountIDsBlackList;
    zSwapV1.zZoneMaximumAmountPerTimePeriod <== rc_zZoneMaximumAmountPerTimePeriod;
    zSwapV1.zZoneTimePeriodPerMaximumAmount <== rc_zZoneTimePeriodPerMaximumAmount;
    zSwapV1.zZoneDataEscrowEncryptedMessage <== rc_zZoneDataEscrowEncryptedMessage;
    zSwapV1.zZoneDataEscrowEncryptedMessageHmac <== rc_zZoneDataEscrowEncryptedMessageHmac;
    zSwapV1.zZoneSealing <== rc_zZoneSealing;
    zSwapV1.kytEdDsaPubKey <== rc_kytEdDsaPubKey;
    zSwapV1.kytEdDsaPubKeyExpiryTime <== rc_kytEdDsaPubKeyExpiryTime;
    zSwapV1.trustProvidersMerkleRoot <== rc_trustProvidersMerkleRoot;
    zSwapV1.kytPathElements <== rc_kytPathElements;
    zSwapV1.kytPathIndices <== rc_kytPathIndices;
    zSwapV1.kytMerkleTreeLeafIDsAndRulesOffset <== rc_kytMerkleTreeLeafIDsAndRulesOffset;
    zSwapV1.kytDepositSignedMessagePackageType <== rc_kytDepositSignedMessagePackageType;
    zSwapV1.kytDepositSignedMessageTimestamp <== rc_kytDepositSignedMessageTimestamp;
    zSwapV1.kytDepositSignedMessageSender <== rc_kytDepositSignedMessageSender;
    zSwapV1.kytDepositSignedMessageReceiver <== rc_kytDepositSignedMessageReceiver;
    zSwapV1.kytDepositSignedMessageToken <== rc_kytDepositSignedMessageToken;
    zSwapV1.kytDepositSignedMessageSessionId <== rc_kytDepositSignedMessageSessionId;
    zSwapV1.kytDepositSignedMessageRuleId <== rc_kytDepositSignedMessageRuleId;
    zSwapV1.kytDepositSignedMessageAmount <== rc_kytDepositSignedMessageAmount;
    zSwapV1.kytDepositSignedMessageChargedAmountZkp <== rc_kytDepositSignedMessageChargedAmountZkp;
    zSwapV1.kytDepositSignedMessageSigner <== rc_kytDepositSignedMessageSigner;
    zSwapV1.kytDepositSignedMessageHash <== rc_kytDepositSignedMessageHash;
    zSwapV1.kytDepositSignature <== rc_kytDepositSignature;
    zSwapV1.kytWithdrawSignedMessagePackageType <== rc_kytWithdrawSignedMessagePackageType;
    zSwapV1.kytWithdrawSignedMessageTimestamp <== rc_kytWithdrawSignedMessageTimestamp;
    zSwapV1.kytWithdrawSignedMessageSender <== rc_kytWithdrawSignedMessageSender;
    zSwapV1.kytWithdrawSignedMessageReceiver <== rc_kytWithdrawSignedMessageReceiver;
    zSwapV1.kytWithdrawSignedMessageToken <== rc_kytWithdrawSignedMessageToken;
    zSwapV1.kytWithdrawSignedMessageSessionId <== rc_kytWithdrawSignedMessageSessionId;
    zSwapV1.kytWithdrawSignedMessageRuleId <== rc_kytWithdrawSignedMessageRuleId;
    zSwapV1.kytWithdrawSignedMessageAmount <== rc_kytWithdrawSignedMessageAmount;
    zSwapV1.kytWithdrawSignedMessageChargedAmountZkp <== rc_kytWithdrawSignedMessageChargedAmountZkp;
    zSwapV1.kytWithdrawSignedMessageSigner <== rc_kytWithdrawSignedMessageSigner;
    zSwapV1.kytWithdrawSignedMessageHash <== rc_kytWithdrawSignedMessageHash;
    zSwapV1.kytWithdrawSignature <== rc_kytWithdrawSignature;
    zSwapV1.kytSignedMessagePackageType <== rc_kytSignedMessagePackageType;
    zSwapV1.kytSignedMessageTimestamp <== rc_kytSignedMessageTimestamp;
    zSwapV1.kytSignedMessageSessionId <== rc_kytSignedMessageSessionId;
    zSwapV1.kytSignedMessageChargedAmountZkp <== rc_kytSignedMessageChargedAmountZkp;
    zSwapV1.kytSignedMessageSigner <== rc_kytSignedMessageSigner;
    zSwapV1.kytSignedMessageDataEscrowHash <== rc_kytSignedMessageDataEscrowHash;
    zSwapV1.kytSignedMessageHash <== rc_kytSignedMessageHash;
    zSwapV1.kytSignature <== rc_kytSignature;
    zSwapV1.dataEscrowPubKey <== rc_dataEscrowPubKey;
    zSwapV1.dataEscrowPubKeyExpiryTime <== rc_dataEscrowPubKeyExpiryTime;
    zSwapV1.dataEscrowEphemeralRandom <== rc_dataEscrowEphemeralRandom;
    zSwapV1.dataEscrowEphemeralPubKeyAx <== rc_dataEscrowEphemeralPubKeyAx;
    zSwapV1.dataEscrowEphemeralPubKeyAy <== rc_dataEscrowEphemeralPubKeyAy;
    zSwapV1.dataEscrowPathElements <== rc_dataEscrowPathElements;
    zSwapV1.dataEscrowPathIndices <== rc_dataEscrowPathIndices;
    zSwapV1.dataEscrowEncryptedMessage <== rc_dataEscrowEncryptedMessage;
    zSwapV1.dataEscrowEncryptedMessageHmac <== rc_dataEscrowEncryptedMessageHmac;
    zSwapV1.daoDataEscrowPubKey <== rc_daoDataEscrowPubKey;
    zSwapV1.daoDataEscrowEphemeralRandom <== rc_daoDataEscrowEphemeralRandom;
    zSwapV1.daoDataEscrowEphemeralPubKeyAx <== rc_daoDataEscrowEphemeralPubKeyAx;
    zSwapV1.daoDataEscrowEphemeralPubKeyAy <== rc_daoDataEscrowEphemeralPubKeyAy;
    zSwapV1.daoDataEscrowEncryptedMessage <== rc_daoDataEscrowEncryptedMessage;
    zSwapV1.daoDataEscrowEncryptedMessageHmac <== rc_daoDataEscrowEncryptedMessageHmac;
    zSwapV1.utxoOutCreateTime <== rc_utxoOutCreateTime;
    zSwapV1.utxoOutAmount <== rc_utxoOutAmount;
    zSwapV1.utxoOutOriginNetworkId <== rc_utxoOutOriginNetworkId;
    zSwapV1.utxoOutTargetNetworkId <== rc_utxoOutTargetNetworkId;
    zSwapV1.utxoOutTargetZoneId <== rc_utxoOutTargetZoneId;
    zSwapV1.utxoOutTargetZoneIdOffset <== rc_utxoOutTargetZoneIdOffset;
    zSwapV1.utxoOutSpendPubKeyRandom <== rc_utxoOutSpendPubKeyRandom;
    zSwapV1.utxoOutRootSpendPubKey <== rc_utxoOutRootSpendPubKey;
    zSwapV1.utxoOutCommitment <== rc_utxoOutCommitment;
    zSwapV1.zAccountUtxoOutZkpAmount <== rc_zAccountUtxoOutZkpAmount;
    zSwapV1.zAccountUtxoOutSpendKeyRandom <== rc_zAccountUtxoOutSpendKeyRandom;
    zSwapV1.zAccountUtxoOutCommitment <== rc_zAccountUtxoOutCommitment;
    zSwapV1.chargedAmountZkp <== rc_chargedAmountZkp;
    zSwapV1.zNetworkId <== rc_zNetworkId;
    zSwapV1.zNetworkChainId <== rc_zNetworkChainId;
    zSwapV1.zNetworkIDsBitMap <== rc_zNetworkIDsBitMap;
    zSwapV1.zNetworkTreeMerkleRoot <== rc_zNetworkTreeMerkleRoot;
    zSwapV1.zNetworkTreePathElements <== rc_zNetworkTreePathElements;
    zSwapV1.zNetworkTreePathIndices <== rc_zNetworkTreePathIndices;
    zSwapV1.staticTreeMerkleRoot <== rc_staticTreeMerkleRoot;
    zSwapV1.forestMerkleRoot <== rc_forestMerkleRoot;
    zSwapV1.taxiMerkleRoot <== rc_taxiMerkleRoot;
    zSwapV1.busMerkleRoot <== rc_busMerkleRoot;
    zSwapV1.ferryMerkleRoot <== rc_ferryMerkleRoot;
    zSwapV1.salt <== rc_salt;
    zSwapV1.saltHash <== rc_saltHash;
    zSwapV1.magicalConstraint <== rc_magicalConstraint;
}
