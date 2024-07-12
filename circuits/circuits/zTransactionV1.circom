//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./zSwapV1Top.circom";

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
    var notZSwap = 0;
    var transactedToken = TransactedTokenIndex();
    var zkpToken = ZkpTokenIndex( notZSwap );
    component zTransactionV1 = ZSwapV1Top( nUtxoIn,
                                           nUtxoOut,
                                           UtxoLeftMerkleTreeDepth,
                                           UtxoMiddleMerkleTreeDepth,
                                           ZNetworkMerkleTreeDepth,
                                           ZAssetMerkleTreeDepth,
                                           ZAccountBlackListMerkleTreeDepth,
                                           ZZoneMerkleTreeDepth,
                                           TrustProvidersMerkleTreeDepth,
                                           notZSwap );

    zTransactionV1.extraInputsHash <== extraInputsHash;
    zTransactionV1.depositAmount <== depositAmount;
    zTransactionV1.withdrawAmount <== withdrawAmount;
    zTransactionV1.addedAmountZkp <== addedAmountZkp;
    zTransactionV1.token[transactedToken] <== token;
    zTransactionV1.tokenId[transactedToken] <== tokenId;
    zTransactionV1.utxoZAsset[transactedToken] <== utxoZAsset;

    zTransactionV1.zAssetId[transactedToken] <== zAssetId;
    zTransactionV1.zAssetToken[transactedToken] <== zAssetToken;
    zTransactionV1.zAssetTokenId[transactedToken] <== zAssetTokenId;
    zTransactionV1.zAssetNetwork[transactedToken] <== zAssetNetwork;
    zTransactionV1.zAssetOffset[transactedToken] <== zAssetOffset;
    zTransactionV1.zAssetWeight[transactedToken] <== zAssetWeight;
    zTransactionV1.zAssetScale[transactedToken] <== zAssetScale;
    zTransactionV1.zAssetMerkleRoot <== zAssetMerkleRoot;
    zTransactionV1.zAssetPathIndices[transactedToken] <== zAssetPathIndices;
    zTransactionV1.zAssetPathElements[transactedToken] <== zAssetPathElements;

    zTransactionV1.zAssetId[zkpToken] <== zAssetIdZkp;
    zTransactionV1.zAssetToken[zkpToken] <== zAssetTokenZkp;
    zTransactionV1.zAssetTokenId[zkpToken] <== zAssetTokenIdZkp;
    zTransactionV1.zAssetNetwork[zkpToken] <== zAssetNetworkZkp;
    zTransactionV1.zAssetOffset[zkpToken] <== zAssetOffsetZkp;
    zTransactionV1.zAssetWeight[zkpToken] <== zAssetWeightZkp;
    zTransactionV1.zAssetScale[zkpToken] <== zAssetScaleZkp;
    zTransactionV1.zAssetPathIndices[zkpToken] <== zAssetPathIndicesZkp;
    zTransactionV1.zAssetPathElements[zkpToken] <== zAssetPathElementsZkp;

    zTransactionV1.forTxReward <== forTxReward;
    zTransactionV1.forUtxoReward <== forUtxoReward;
    zTransactionV1.forDepositReward <== forDepositReward;
    zTransactionV1.spendTime <== spendTime;

    zTransactionV1.utxoInSpendPrivKey <== utxoInSpendPrivKey;
    zTransactionV1.utxoInSpendKeyRandom <== utxoInSpendKeyRandom;
    zTransactionV1.utxoInAmount <== utxoInAmount;
    zTransactionV1.utxoInOriginZoneId <== utxoInOriginZoneId;
    zTransactionV1.utxoInOriginZoneIdOffset <== utxoInOriginZoneIdOffset;
    zTransactionV1.utxoInOriginNetworkId <== utxoInOriginNetworkId;
    zTransactionV1.utxoInTargetNetworkId <== utxoInTargetNetworkId;
    zTransactionV1.utxoInCreateTime <== utxoInCreateTime;
    zTransactionV1.utxoInZAccountId <== utxoInZAccountId;
    zTransactionV1.utxoInMerkleTreeSelector <== utxoInMerkleTreeSelector;
    zTransactionV1.utxoInPathIndices <== utxoInPathIndices;
    zTransactionV1.utxoInPathElements <== utxoInPathElements;
    zTransactionV1.utxoInNullifier <== utxoInNullifier;
    zTransactionV1.utxoInDataEscrowPubKey <== utxoInDataEscrowPubKey;

    zTransactionV1.zAccountUtxoInId <== zAccountUtxoInId;
    zTransactionV1.zAccountUtxoInZkpAmount <== zAccountUtxoInZkpAmount;
    zTransactionV1.zAccountUtxoInPrpAmount <== zAccountUtxoInPrpAmount;
    zTransactionV1.zAccountUtxoInZoneId <== zAccountUtxoInZoneId;
    zTransactionV1.zAccountUtxoInNetworkId <== zAccountUtxoInNetworkId;
    zTransactionV1.zAccountUtxoInExpiryTime <== zAccountUtxoInExpiryTime;
    zTransactionV1.zAccountUtxoInNonce <== zAccountUtxoInNonce;
    zTransactionV1.zAccountUtxoInTotalAmountPerTimePeriod <== zAccountUtxoInTotalAmountPerTimePeriod;
    zTransactionV1.zAccountUtxoInCreateTime <== zAccountUtxoInCreateTime;
    zTransactionV1.zAccountUtxoInRootSpendPubKey <== zAccountUtxoInRootSpendPubKey;
    zTransactionV1.zAccountUtxoInReadPubKey <== zAccountUtxoInReadPubKey;
    zTransactionV1.zAccountUtxoInNullifierPubKey <== zAccountUtxoInNullifierPubKey;
    zTransactionV1.zAccountUtxoInMasterEOA <== zAccountUtxoInMasterEOA;
    zTransactionV1.zAccountUtxoInSpendPrivKey <== zAccountUtxoInSpendPrivKey;
    zTransactionV1.zAccountUtxoInReadPrivKey <== zAccountUtxoInReadPrivKey;
    zTransactionV1.zAccountUtxoInNullifierPrivKey <== zAccountUtxoInNullifierPrivKey;
    zTransactionV1.zAccountUtxoInMerkleTreeSelector <== zAccountUtxoInMerkleTreeSelector;
    zTransactionV1.zAccountUtxoInPathIndices <== zAccountUtxoInPathIndices;
    zTransactionV1.zAccountUtxoInPathElements <== zAccountUtxoInPathElements;
    zTransactionV1.zAccountUtxoInNullifier <== zAccountUtxoInNullifier;

    zTransactionV1.zAccountBlackListLeaf <== zAccountBlackListLeaf;
    zTransactionV1.zAccountBlackListMerkleRoot <== zAccountBlackListMerkleRoot;
    zTransactionV1.zAccountBlackListPathElements <== zAccountBlackListPathElements;
    zTransactionV1.zZoneOriginZoneIDs <== zZoneOriginZoneIDs;
    zTransactionV1.zZoneTargetZoneIDs <== zZoneTargetZoneIDs;
    zTransactionV1.zZoneNetworkIDsBitMap <== zZoneNetworkIDsBitMap;
    zTransactionV1.zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;
    zTransactionV1.zZoneKycExpiryTime <== zZoneKycExpiryTime;
    zTransactionV1.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    zTransactionV1.zZoneDepositMaxAmount <== zZoneDepositMaxAmount;
    zTransactionV1.zZoneWithdrawMaxAmount <== zZoneWithdrawMaxAmount;
    zTransactionV1.zZoneInternalMaxAmount <== zZoneInternalMaxAmount;
    zTransactionV1.zZoneMerkleRoot <== zZoneMerkleRoot;
    zTransactionV1.zZonePathElements <== zZonePathElements;
    zTransactionV1.zZonePathIndices <== zZonePathIndices;
    zTransactionV1.zZoneEdDsaPubKey <== zZoneEdDsaPubKey;
    zTransactionV1.zZoneDataEscrowEphemeralRandom <== zZoneDataEscrowEphemeralRandom;
    zTransactionV1.zZoneDataEscrowEphemeralPubKeyAx <== zZoneDataEscrowEphemeralPubKeyAx;
    zTransactionV1.zZoneDataEscrowEphemeralPubKeyAy <== zZoneDataEscrowEphemeralPubKeyAy;
    zTransactionV1.zZoneZAccountIDsBlackList <== zZoneZAccountIDsBlackList;
    zTransactionV1.zZoneMaximumAmountPerTimePeriod <== zZoneMaximumAmountPerTimePeriod;
    zTransactionV1.zZoneTimePeriodPerMaximumAmount <== zZoneTimePeriodPerMaximumAmount;
    zTransactionV1.zZoneDataEscrowEncryptedMessageAx <== zZoneDataEscrowEncryptedMessageAx;
    zTransactionV1.zZoneDataEscrowEncryptedMessageAy <== zZoneDataEscrowEncryptedMessageAy;
    zTransactionV1.zZoneSealing <== zZoneSealing;

    zTransactionV1.kytEdDsaPubKey <== kytEdDsaPubKey;
    zTransactionV1.kytEdDsaPubKeyExpiryTime <== kytEdDsaPubKeyExpiryTime;
    zTransactionV1.trustProvidersMerkleRoot <== trustProvidersMerkleRoot;
    zTransactionV1.kytPathElements <== kytPathElements;
    zTransactionV1.kytPathIndices <== kytPathIndices;
    zTransactionV1.kytMerkleTreeLeafIDsAndRulesOffset <== kytMerkleTreeLeafIDsAndRulesOffset;
    zTransactionV1.kytDepositSignedMessagePackageType <== kytDepositSignedMessagePackageType;
    zTransactionV1.kytDepositSignedMessageTimestamp <== kytDepositSignedMessageTimestamp;
    zTransactionV1.kytDepositSignedMessageSender <== kytDepositSignedMessageSender;
    zTransactionV1.kytDepositSignedMessageReceiver <== kytDepositSignedMessageReceiver;
    zTransactionV1.kytDepositSignedMessageToken <== kytDepositSignedMessageToken;
    zTransactionV1.kytDepositSignedMessageSessionId <== kytDepositSignedMessageSessionId;
    zTransactionV1.kytDepositSignedMessageRuleId <== kytDepositSignedMessageRuleId;
    zTransactionV1.kytDepositSignedMessageAmount <== kytDepositSignedMessageAmount;
    zTransactionV1.kytDepositSignedMessageSigner <== kytDepositSignedMessageSigner;
    zTransactionV1.kytDepositSignedMessageChargedAmountZkp <== kytDepositSignedMessageChargedAmountZkp;
    zTransactionV1.kytDepositSignedMessageHash <== kytDepositSignedMessageHash;
    zTransactionV1.kytDepositSignature <== kytDepositSignature;

    zTransactionV1.kytWithdrawSignedMessagePackageType <== kytWithdrawSignedMessagePackageType;
    zTransactionV1.kytWithdrawSignedMessageTimestamp <== kytWithdrawSignedMessageTimestamp;
    zTransactionV1.kytWithdrawSignedMessageSender <== kytWithdrawSignedMessageSender;
    zTransactionV1.kytWithdrawSignedMessageReceiver <== kytWithdrawSignedMessageReceiver;
    zTransactionV1.kytWithdrawSignedMessageToken <== kytWithdrawSignedMessageToken;
    zTransactionV1.kytWithdrawSignedMessageSessionId <== kytWithdrawSignedMessageSessionId;
    zTransactionV1.kytWithdrawSignedMessageRuleId <== kytWithdrawSignedMessageRuleId;
    zTransactionV1.kytWithdrawSignedMessageAmount <== kytWithdrawSignedMessageAmount;
    zTransactionV1.kytWithdrawSignedMessageChargedAmountZkp <== kytWithdrawSignedMessageChargedAmountZkp;
    zTransactionV1.kytWithdrawSignedMessageSigner <== kytWithdrawSignedMessageSigner;
    zTransactionV1.kytWithdrawSignedMessageHash <== kytWithdrawSignedMessageHash;
    zTransactionV1.kytWithdrawSignature <== kytWithdrawSignature;

    zTransactionV1.kytSignedMessagePackageType <== kytSignedMessagePackageType;
    zTransactionV1.kytSignedMessageTimestamp <== kytSignedMessageTimestamp;
    zTransactionV1.kytSignedMessageSessionId <== kytSignedMessageSessionId;
    zTransactionV1.kytSignedMessageChargedAmountZkp <== kytSignedMessageChargedAmountZkp;
    zTransactionV1.kytSignedMessageSigner <== kytSignedMessageSigner;
    zTransactionV1.kytSignedMessageDataEscrowHash <== kytSignedMessageDataEscrowHash;
    zTransactionV1.kytSignedMessageHash <== kytSignedMessageHash;
    zTransactionV1.kytSignature <== kytSignature;

    zTransactionV1.dataEscrowPubKey <== dataEscrowPubKey;
    zTransactionV1.dataEscrowPubKeyExpiryTime <== dataEscrowPubKeyExpiryTime;
    zTransactionV1.dataEscrowEphemeralRandom <== dataEscrowEphemeralRandom;
    zTransactionV1.dataEscrowEphemeralPubKeyAx <== dataEscrowEphemeralPubKeyAx;
    zTransactionV1.dataEscrowEphemeralPubKeyAy <== dataEscrowEphemeralPubKeyAy;
    zTransactionV1.dataEscrowPathElements <== dataEscrowPathElements;
    zTransactionV1.dataEscrowPathIndices <== dataEscrowPathIndices;

    zTransactionV1.dataEscrowEncryptedMessageAx <== dataEscrowEncryptedMessageAx;
    zTransactionV1.dataEscrowEncryptedMessageAy <== dataEscrowEncryptedMessageAy;

    zTransactionV1.daoDataEscrowPubKey <== daoDataEscrowPubKey;
    zTransactionV1.daoDataEscrowEphemeralRandom <== daoDataEscrowEphemeralRandom;
    zTransactionV1.daoDataEscrowEphemeralPubKeyAx <== daoDataEscrowEphemeralPubKeyAx;
    zTransactionV1.daoDataEscrowEphemeralPubKeyAy <== daoDataEscrowEphemeralPubKeyAy;

    zTransactionV1.daoDataEscrowEncryptedMessageAx <== daoDataEscrowEncryptedMessageAx;
    zTransactionV1.daoDataEscrowEncryptedMessageAy <== daoDataEscrowEncryptedMessageAy;

    zTransactionV1.utxoOutCreateTime <== utxoOutCreateTime;
    zTransactionV1.utxoOutAmount <== utxoOutAmount;
    zTransactionV1.utxoOutOriginNetworkId <== utxoOutOriginNetworkId;
    zTransactionV1.utxoOutTargetNetworkId <== utxoOutTargetNetworkId;
    zTransactionV1.utxoOutTargetZoneId <== utxoOutTargetZoneId;
    zTransactionV1.utxoOutTargetZoneIdOffset <== utxoOutTargetZoneIdOffset;
    zTransactionV1.utxoOutSpendPubKeyRandom <== utxoOutSpendPubKeyRandom;
    zTransactionV1.utxoOutRootSpendPubKey <== utxoOutRootSpendPubKey;
    zTransactionV1.utxoOutCommitment <== utxoOutCommitment;
    zTransactionV1.zAccountUtxoOutZkpAmount <== zAccountUtxoOutZkpAmount;
    zTransactionV1.zAccountUtxoOutSpendKeyRandom <== zAccountUtxoOutSpendKeyRandom;
    zTransactionV1.zAccountUtxoOutCommitment <== zAccountUtxoOutCommitment;
    zTransactionV1.chargedAmountZkp <== chargedAmountZkp;

    zTransactionV1.zNetworkId <== zNetworkId;
    zTransactionV1.zNetworkChainId <== zNetworkChainId;
    zTransactionV1.zNetworkIDsBitMap <== zNetworkIDsBitMap;
    zTransactionV1.zNetworkTreeMerkleRoot <== zNetworkTreeMerkleRoot;
    zTransactionV1.zNetworkTreePathElements <== zNetworkTreePathElements;
    zTransactionV1.zNetworkTreePathIndices <== zNetworkTreePathIndices;

    zTransactionV1.staticTreeMerkleRoot <== staticTreeMerkleRoot;

    zTransactionV1.forestMerkleRoot <== forestMerkleRoot;
    zTransactionV1.taxiMerkleRoot <== taxiMerkleRoot;
    zTransactionV1.busMerkleRoot <== busMerkleRoot;
    zTransactionV1.ferryMerkleRoot <== ferryMerkleRoot;
    zTransactionV1.salt <== salt;
    zTransactionV1.saltHash <== saltHash;
    zTransactionV1.magicalConstraint <== magicalConstraint;
}
