//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./templates/rangeCheck.circom";

template ZSwapV1RangeCheck( nUtxoIn,
                            nUtxoOut,
                            UtxoLeftMerkleTreeDepth,
                            UtxoMiddleMerkleTreeDepth,
                            ZNetworkMerkleTreeDepth,
                            ZAssetMerkleTreeDepth,
                            ZAccountBlackListMerkleTreeDepth,
                            ZZoneMerkleTreeDepth,
                            TrustProvidersMerkleTreeDepth,
                            isSwap ) {
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
    signal input depositChange;
    signal input withdrawAmount;   // public
    signal input withdrawChange;
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

    signal input dataEscrowEncryptedMessageAx[dataEscrowEncryptedPoints]; // public
    signal input dataEscrowEncryptedMessageAy[dataEscrowEncryptedPoints];

    // dao data escrow
    signal input daoDataEscrowPubKey[2];
    signal input daoDataEscrowEphemeralRandom;
    signal input daoDataEscrowEphemeralPubKeyAx; // public
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

    //////////////////////////////////////////////////////////////////////////////////////////////
    // Format of comments:
    // Field name - Size of the field
    // Public Signal?
    // Maximum supported range | Within SNARK FIELD (254 bits) | Within Suborder
    // Should it be checked in SC?

    // SNARK FIELD SIZE - 21888242871839275222246405745257275088548364400416034343698204186575808495617
    //////////////////////////////////////////////////////////////////////////////////////////////

    // extraInputsHash - 256 bits
    // Public signal
    // Must be within the SNARK_FIELD
    // Must be checked as part of SC

    // depositAmount - 252 bits
    // Public signal
    // Supported range - [0 to (2**252 - 1)]
    // Todo - Can be restricted to be 250 bits?
    component customRangeCheck_DepositAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_DepositAmount.in <== depositAmount;

    // depositChange - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restricted to be 250 bits?
    component customRangeCheck_DepositChange = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_DepositChange.in <== depositChange;

    // withdrawAmount  - 252 bits
    // Public signal
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restricted to be 250 bits?
    component customRangeCheck_WithdrawAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_WithdrawAmount.in <== withdrawAmount;

    // withdrawChange - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restricted to be 250 bits?
    component customRangeCheck_WithdrawChange = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_WithdrawChange.in <== withdrawChange;

    // addedAmountZkp - 252 bits
    // Public signal - Checked as part of Smart Contract
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restricted to be 250 bits?
    component customRangeCheck_DonatedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_DonatedAmountZkp.in <== addedAmountZkp;

    // token - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_Token[arraySizeInCaseOfSwap];

    // tokenId - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Must be checked from SC end.

    // utxoZAsset - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_UtxoZAsset[arraySizeInCaseOfSwap];
    for(var i = 0; i < arraySizeInCaseOfSwap; i++) {

        customRangeCheck_Token[i] = RangeCheckSingleSignal(160,(2**160 - 1),0);
        customRangeCheck_Token[i].in <== token[i];

        customRangeCheck_UtxoZAsset[i] = RangeCheckSingleSignal(64,(2**64 - 1),0);
        customRangeCheck_UtxoZAsset[i].in <== utxoZAsset[i];
    }

    // zAssetId - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZAssetId[zAssetArraySize];

    // zAssetToken - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_ZAssetToken[zAssetArraySize];

    // zAssetTokenId - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Must be checked from SC end

    // zAssetNetwork - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_ZAssetNetwork[zAssetArraySize];

    // zAssetOffset - 6 bits
    // Supported range - [0 to 32]
    // Although it is a 6 bits field, maximum value that it should be constrained to is 32.
    component customRangeCheck_ZAssetOffset[zAssetArraySize];

    // zAssetWeight - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ZAssetWeight[zAssetArraySize];

    // zAssetScale - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    component customRangeCheck_ZAssetScale[zAssetArraySize];

    // zAssetMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAssetPathIndices
    // ToDo - Path Indices should be fixed to 1 bit? - YES , please FIXME
    component customRangeCheck_ZAssetPathIndices[zAssetArraySize];

    // zAssetPathElements TODO: FIXME - why SC checked ?
    // Must be within the SNARK_FIELD
    // component customRangeCheck_ZAssetPathElements[zAssetArraySize];

    for( var i = 0; i < zAssetArraySize; i++ ) {
        customRangeCheck_ZAssetId[i] = RangeCheckSingleSignal(64,(2**64 - 1),0);
        customRangeCheck_ZAssetId[i].in <== zAssetId[i];

        customRangeCheck_ZAssetToken[i] = RangeCheckSingleSignal(160,(2**160 - 1),0);
        customRangeCheck_ZAssetToken[i].in <== zAssetToken[i];

        // zAssetTokenId - 256 bits
        // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
        // Must be checked from SC end

        customRangeCheck_ZAssetNetwork[i] = RangeCheckSingleSignal(6,(2**6 - 1),0);
        customRangeCheck_ZAssetNetwork[i].in <== zAssetNetwork[i];

        customRangeCheck_ZAssetOffset[i] = RangeCheckSingleSignal(6,32,0);
        customRangeCheck_ZAssetOffset[i].in <== zAssetOffset[i];

        customRangeCheck_ZAssetWeight[i] = RangeCheckSingleSignal(32,(2**32 - 1),0);
        customRangeCheck_ZAssetWeight[i].in <== zAssetWeight[i];

        customRangeCheck_ZAssetScale[i] = RangeCheckSingleSignal(252,(2**252 - 1),0);
        customRangeCheck_ZAssetScale[i].in <== zAssetScale[i];

        // zAssetPathIndices
        // ToDo - Path Indices should be fixed to 1 bit? - YES, please FIXME
        customRangeCheck_ZAssetPathIndices[i] = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
        customRangeCheck_ZAssetPathIndices[i].in <== zAssetPathIndices[i];

        // zAssetPathElements TODO: FIXME - why SC checked ? It should be 254 bit since its hash
        // Must be within the SNARK_FIELD
        //        customRangeCheck_ZAssetPathElements[i] = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
        //        customRangeCheck_ZAssetPathElements[i].in <== zAssetPathElements[i];
    }

    // forTxReward - 40 bits
    // Supported range - [0 to (2**40 - 1)]
    component customRangeCheck_ForTxReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheck_ForTxReward.in <== forTxReward;

    // forUtxoReward - 40 bits
    // Supported range - [0 to (2**40 - 1)]
    component customRangeCheck_ForUtxoReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheck_ForUtxoReward.in <== forUtxoReward;

    // forDepositReward - 40 bits
    // Supported range - [0 to (2**40 - 1)]
    component customRangeCheck_ForDepositReward = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheck_ForDepositReward.in <== forDepositReward;

    // spendTime - 32 bits
    // Public signal
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ForSpendTime = RangeCheckSingleSignal(40,(2**40 - 1),0);
    customRangeCheck_ForSpendTime.in <== spendTime;

    // utxoInSpendPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // utxoInSpendKeyRandom
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Must be checked from SC end

    // utxoInAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Can be restricted to be 250 bits?
    component customRangeCheck_UtxoInAmount = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheck_UtxoInAmount.in <== utxoInAmount;

    // utxoInOriginZoneId - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheck_UtxoInOriginZoneId = RangeCheckGroupOfSignals(2, 16,(2**16 - 1),0);
    customRangeCheck_UtxoInOriginZoneId.in <== utxoInOriginZoneId;

    // utxoInOriginZoneIdOffset - 4 bits
    // Supported range - [0 to (2**4 - 1)]
    component customRangeCheck_UtxoInOriginZoneIdOffset = RangeCheckGroupOfSignals(2, 4,(2**4 - 1),0);
    customRangeCheck_UtxoInOriginZoneIdOffset.in <== utxoInOriginZoneIdOffset;

    // utxoInOriginNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_UtxoInOriginNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0);
    customRangeCheck_UtxoInOriginNetworkId.in <== utxoInOriginNetworkId;

    // utxoInTargetNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_UtxoInTargetNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0);
    customRangeCheck_UtxoInTargetNetworkId.in <== utxoInTargetNetworkId;

    // utxoInCreateTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_UtxoInCreateTime = RangeCheckGroupOfSignals(2, 32,(2**32 - 1),0);
    customRangeCheck_UtxoInCreateTime.in <== utxoInCreateTime;

    // utxoInZAccountId - 24 bits
    // Supported range - [0 to (2**24 - 1)]
    component customRangeCheck_UtxoInZAccountId = RangeCheckGroupOfSignals(2, 24,(2**24 - 1),0);
    customRangeCheck_UtxoInZAccountId.in <== utxoInZAccountId;

    // utxoInMerkleTreeSelector - 2 bits
    // ToDo - bit size is 2 bits
    component customRangeCheck_UtxoInMerkleTreeSelectorUtxo0 = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheck_UtxoInMerkleTreeSelectorUtxo0.in <== utxoInMerkleTreeSelector[0];

    component customRangeCheck_UtxoInMerkleTreeSelectorUtxo1 = RangeCheckGroupOfSignals(2, 252,(2**252 - 1),0);
    customRangeCheck_UtxoInMerkleTreeSelectorUtxo1.in <== utxoInMerkleTreeSelector[1];

    // utxoInPathIndices
    // ToDo - Path Indices should be fixed to 1 bit
    // component customRangeCheck_UtxoInPathIndices = RangeCheckGroupOfSignals(32, 252,(2**252 - 1),0);
    // customRangeCheck_UtxoInPathIndices.in <== utxoInPathIndices[0];

    // utxoInPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // utxoInNullifier
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // utxoInDataEscrowPubKey
    // Must be within the SNARK_FIELD

    // zAccountUtxoInId - 24 bits
    // Supported range - [0 to (2**24 - 1)]
    component customRangeCheck_ZAccountUtxoInId = RangeCheckSingleSignal(24,(2**24 - 1),0);
    customRangeCheck_ZAccountUtxoInId.in <== zAccountUtxoInId;

    // zAccountUtxoInZkpAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - cross verify if it is 64 bits?
    component customRangeCheck_ZAccountUtxoInZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZAccountUtxoInZkpAmount.in <== zAccountUtxoInZkpAmount;

    // zAccountUtxoInPrpAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZAccountUtxoInPrpAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_ZAccountUtxoInPrpAmount.in <== zAccountUtxoInPrpAmount;

    // zAccountUtxoInZoneId - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheck_ZAccountUtxoInZoneId = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheck_ZAccountUtxoInZoneId.in <== zAccountUtxoInZoneId;

    // zAccountUtxoInNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_ZAccountUtxoInNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheck_ZAccountUtxoInNetworkId.in <== zAccountUtxoInNetworkId;

    // zAccountUtxoInExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ZAccountUtxoInExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_ZAccountUtxoInExpiryTime.in <== zAccountUtxoInExpiryTime;

    // zAccountUtxoInNonce - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    // ToDo - check if this should be constrained or not?
    component customRangeCheck_ZAccountUtxoInNonce = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheck_ZAccountUtxoInNonce.in <== zAccountUtxoInNonce;

    // zAccountUtxoInTotalAmountPerTimePeriod - 256 bits
    // ToDo - should we constraint it to 252?
    component customRangeCheck_ZAccountUtxoInTotalAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZAccountUtxoInTotalAmountPerTimePeriod.in <== zAccountUtxoInTotalAmountPerTimePeriod;

    // zAccountUtxoInCreateTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ZAccountUtxoInCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_ZAccountUtxoInCreateTime.in <== zAccountUtxoInCreateTime;

    // zAccountUtxoInRootSpendPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoInReadPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoInNullifierPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoInMasterEOA - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_ZAccountUtxoInMasterEOA = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_ZAccountUtxoInMasterEOA.in <== zAccountUtxoInMasterEOA;

    // zAccountUtxoInSpendPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInReadPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInNullifierPrivKey
    // Must be within the Baby Jubjub Suborder
    // Should be checked as part of the SC

    // zAccountUtxoInMerkleTreeSelector - 2 bits
    // Supported range - [0 to (2**2 - 1)]
    component customRangeCheck_ZAccountUtxoInMerkleTreeSelector = RangeCheckGroupOfSignals(2, 2, (2**2 - 1), 0);
    customRangeCheck_ZAccountUtxoInMerkleTreeSelector.in <== zAccountUtxoInMerkleTreeSelector;

    // zAccountUtxoInPathIndices
    // ToDo - Path Indices should be fixed to 1 bit
    // component customRangeCheck_ZAccountUtxoInPathIndices = RangeCheckGroupOfSignals(32, 252, (2**252 - 1), 0);
    // customRangeCheck_ZAccountUtxoInPathIndices.in <== zAccountUtxoInPathIndices;

    // zAccountUtxoInPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoInNullifier
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListLeaf - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - should we restrict to 252?
    component customRangeCheck_ZAccountBlackListLeaf = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZAccountBlackListLeaf.in <== zAccountBlackListLeaf;

    // zAccountBlackListMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountBlackListPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZoneOriginZoneIDs - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - check if this needs to be restricted to 252 bit?
    component customRangeCheck_ZZoneOriginZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZZoneOriginZoneIDs.in <== zZoneOriginZoneIDs;

    // zZoneTargetZoneIDs - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - check if this needs to be restricted to 252 bits?
    component customRangeCheck_ZZoneTargetZoneIDs = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZZoneTargetZoneIDs.in <== zZoneTargetZoneIDs;

    // zZoneNetworkIDsBitMap - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZZoneNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_ZZoneNetworkIDsBitMap.in <== zZoneNetworkIDsBitMap;

    // zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList - 240 bits
    // Supported range - [0 to (2**240 - 1)]
    component customRangeCheck_ZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList = RangeCheckSingleSignal(240,(2**240 - 1),0);
    customRangeCheck_ZZoneTrustProvidersMerkleTreeLeafIDsAndRulesList.in <== zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList;

    // zZoneKycExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ZZoneKycExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_ZZoneKycExpiryTime.in <== zZoneKycExpiryTime;

    // zZoneKytExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ZZoneKytExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_ZZoneKytExpiryTime.in <== zZoneKytExpiryTime;

    // zZoneDepositMaxAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZZoneDepositMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_ZZoneDepositMaxAmount.in <== zZoneDepositMaxAmount;

    // zZoneWithrawMaxAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZZoneWithrawMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_ZZoneWithrawMaxAmount.in <== zZoneWithrawMaxAmount;

    // zZoneInternalMaxAmount - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZZoneInternalMaxAmount = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_ZZoneInternalMaxAmount.in <== zZoneInternalMaxAmount;

    // zZoneMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZonePathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zZonePathIndices
    // ToDo - should be changed to 1 bit

    // zZoneEdDsaPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneDataEscrowEphemeralRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneDataEscrowEphemeralPubKeyAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneDataEscrowEphemeralPubKeyAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zZoneZAccountIDsBlackList - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // ToDo - Should we restrict to 252?
    component customRangeCheck_ZZoneZAccountIDsBlackList = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZZoneZAccountIDsBlackList.in <== zZoneZAccountIDsBlackList;

    // zZoneMaximumAmountPerTimePeriod - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheck_ZZoneMaximumAmountPerTimePeriod = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheck_ZZoneMaximumAmountPerTimePeriod.in <== zZoneMaximumAmountPerTimePeriod;

    // zZoneTimePeriodPerMaximumAmount - 32 bit
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_ZZoneTimePeriodPerMaximumAmount = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_ZZoneTimePeriodPerMaximumAmount.in <== zZoneTimePeriodPerMaximumAmount;

    // zZoneSealing - 1 bit
    zZoneSealing - ( zZoneSealing * zZoneSealing ) === 0;

    // zZoneDataEscrowEncryptedMessageAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheck_ZZoneDataEscrowEncryptedMessageAx = RangeCheckGroupOfSignals(1,252,(2**252 - 1),0);
    // customRangeCheck_ZZoneDataEscrowEncryptedMessageAx.in <== zZoneDataEscrowEncryptedMessageAx;

    // zZoneDataEscrowEncryptedMessageAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheck_ZZoneDataEscrowEncryptedMessageAy = RangeCheckGroupOfSignals(1,252,(2**252 - 1),0);
    // customRangeCheck_ZZoneDataEscrowEncryptedMessageAy.in <== zZoneDataEscrowEncryptedMessageAy;

    // kytEdDsaPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC
    // component customRangeCheck_KytEdDsaPubKey = RangeCheckGroupOfSignals(2,252,(2**252 - 1),0);
    // customRangeCheck_KytEdDsaPubKey.in <== kytEdDsaPubKey;

    // kytEdDsaPubKeyExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_KytEdDsaPubKeyExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_KytEdDsaPubKeyExpiryTime.in <== kytEdDsaPubKeyExpiryTime;

    // trustProvidersMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kytPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kytPathIndices - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - Needs to check 1 bit?
    // component customRangeCheck_KytPathIndices = RangeCheckGroupOfSignals(16,252,(2**252 - 1),0);
    // customRangeCheck_KytPathIndices.in <== kytPathIndices;

    // kytMerkleTreeLeafIDsAndRulesOffset - 16 bits
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheck_KytMerkleTreeLeafIDsAndRulesOffset = RangeCheckSingleSignal(16,(2**16 - 1),0);
    customRangeCheck_KytMerkleTreeLeafIDsAndRulesOffset.in <== kytMerkleTreeLeafIDsAndRulesOffset;

    // kytDepositSignedMessagePackageType - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheck_KytDepositSignedMessagePackageType = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheck_KytDepositSignedMessagePackageType.in <== kytDepositSignedMessagePackageType;

    // kytDepositSignedMessageTimestamp - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_KytDepositSignedMessageTimestamp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_KytDepositSignedMessageTimestamp.in <== kytDepositSignedMessageTimestamp;

    // kytDepositSignedMessageSender - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytDepositSignedMessageSender = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytDepositSignedMessageSender.in <== kytDepositSignedMessageSender;

    // kytDepositSignedMessageReceiver - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytDepositSignedMessageReceiver = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytDepositSignedMessageReceiver.in <== kytDepositSignedMessageReceiver;

    // kytDepositSignedMessageToken - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytDepositSignedMessageToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytDepositSignedMessageToken.in <== kytDepositSignedMessageToken;

    // kytDepositSignedMessageSessionId - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - if it is strictly 256 then it needs to be checked in SC?
    // component customRangeCheck_KytDepositSignedMessageSessionId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheck_KytDepositSignedMessageSessionId.in <== kytDepositSignedMessageSessionId;

    // kytDepositSignedMessageRuleId - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheck_KytDepositSignedMessageRuleId = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheck_KytDepositSignedMessageRuleId.in <== kytDepositSignedMessageRuleId;

    // kytDepositSignedMessageAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheck_KytDepositSignedMessageAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytDepositSignedMessageAmount.in <== kytDepositSignedMessageAmount;

    // kytDepositSignedMessageChargedAmountZkp - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    component customRangeCheck_KytDepositSignedMessageChargedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytDepositSignedMessageChargedAmountZkp.in <== kytDepositSignedMessageChargedAmountZkp;

    // kytDepositSignedMessageSigner - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytDepositSignedMessageSigner = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytDepositSignedMessageSigner.in <== kytDepositSignedMessageSigner;

    // kytDepositSignedMessageHash
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // kytDepositSignature
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheck_KytDepositSignature = RangeCheckGroupOfSignals(3,252,(2**252 - 1),0);
    // customRangeCheck_KytDepositSignature.in <== kytDepositSignature;

    // kytWithdrawSignedMessagePackageType - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheck_KytWithdrawSignedMessagePackageType = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheck_KytWithdrawSignedMessagePackageType.in <== kytWithdrawSignedMessagePackageType;

    // kytWithdrawSignedMessageTimestamp - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageTimestamp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageTimestamp.in <== kytWithdrawSignedMessageTimestamp;

    // kytWithdrawSignedMessageSender - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageSender = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageSender.in <== kytWithdrawSignedMessageSender;

    // kytWithdrawSignedMessageReceiver - 160 bits
    // Public signal
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageReceiver = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageReceiver.in <== kytWithdrawSignedMessageReceiver;

    // kytWithdrawSignedMessageToken - 160 bits ERC20 token
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageToken = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageToken.in <== kytWithdrawSignedMessageToken;

    // kytWithdrawSignedMessageSessionId - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - session id strictly 256 bits?
    component customRangeCheck_KytWithdrawSignedMessageSessionId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageSessionId.in <== kytWithdrawSignedMessageSessionId;

    // kytWithdrawSignedMessageRuleId - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageRuleId = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageRuleId.in <== kytWithdrawSignedMessageRuleId;

    // kytWithdrawSignedMessageChargedAmountZkp - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageChargedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageChargedAmountZkp.in <== kytWithdrawSignedMessageChargedAmountZkp;

    // kytWithdrawSignedMessageAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheck_KytWithdrawSignedMessageAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageAmount.in <== kytWithdrawSignedMessageAmount;

    // kytWithdrawSignedMessageSigner - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytWithdrawSignedMessageSigner = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytWithdrawSignedMessageSigner.in <== kytWithdrawSignedMessageSigner;

    // kytWithdrawSignedMessageHash
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheck_KytWithdrawSignedMessageHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheck_KytWithdrawSignedMessageHash.in <== kytWithdrawSignedMessageHash;

    // kytWithdrawSignature
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheck_KytWithdrawSignature = RangeCheckGroupOfSignals(3,252,(2**252 - 1),0);
    // customRangeCheck_KytWithdrawSignature.in <== kytWithdrawSignature;

    // kytSignedMessagePackageType - 8 bits
    // Supported range - [0 to (2**8 - 1)]
    component customRangeCheck_KytSignedMessagePackageType = RangeCheckSingleSignal(8,(2**8 - 1),0);
    customRangeCheck_KytSignedMessagePackageType.in <== kytSignedMessagePackageType;

    // kytSignedMessageTimestamp - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_KytSignedMessageTimestamp = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_KytSignedMessageTimestamp.in <== kytSignedMessageTimestamp;

    // kytSignedMessageSessionId - 256 bits
    // Supported range - [0 to (2**252 - 1)]
    // ToDo - session id strictly 256 bits?
    component customRangeCheck_KytSignedMessageSessionId = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytSignedMessageSessionId.in <== kytSignedMessageSessionId;

    // kytSignedMessageChargedAmountZkp - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    component customRangeCheck_KytSignedMessageChargedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_KytSignedMessageChargedAmountZkp.in <== kytSignedMessageChargedAmountZkp;

    // kytSignedMessageSigner - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytSignedMessageSigner = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytSignedMessageSigner.in <== kytSignedMessageSigner;

    // kytSignedMessageDataEscrowHash - 160 bits
    // Supported range - [0 to (2**160 - 1)]
    component customRangeCheck_KytSignedMessageDataEscrowHash = RangeCheckSingleSignal(160,(2**160 - 1),0);
    customRangeCheck_KytSignedMessageDataEscrowHash.in <== kytSignedMessageDataEscrowHash;

    // kytSignedMessageHash
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheck_KytSignedMessageHash = RangeCheckSingleSignal(252,(2**252 - 1),0);
    // customRangeCheck_KytSignedMessageHash.in <== kytSignedMessageHash;

    // kytSignature
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC
    // component customRangeCheck_KytSignature = RangeCheckGroupOfSignals(3,252,(2**252 - 1),0);
    // customRangeCheck_KytSignature.in <== kytSignature;


    // dataEscrowPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowPubKeyExpiryTime - 32 bits
    // Supported range - [0 to (2**32 - 1)]
    component customRangeCheck_DataEscrowPubKeyExpiryTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_DataEscrowPubKeyExpiryTime.in <== dataEscrowPubKeyExpiryTime;

    // dataEscrowEphemeralRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowEphemeralPubKeyAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowEphemeralPubKeyAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // dataEscrowPathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // ToDo - Restrict path indices to 1 bit?
    // component customRangeCheck_DataEscrowPathIndices = RangeCheckGroupOfSignals(16, 252,(2**252 - 1),0);
    // customRangeCheck_DataEscrowPathIndices.in <== dataEscrowPathIndices;

    // dataEscrowEncryptedMessageAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // dataEscrowEncryptedMessageAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEphemeralRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEphemeralPubKeyAx - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEphemeralPubKeyAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEncryptedMessageAx - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // daoDataEscrowEncryptedMessageAy - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here.
    // Should be checked as part of the SC

    // utxoOutCreateTime - 32 bits
    // Public signal
    // Supported range - [0 to (2**32 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheck_UtxoOutCreateTime = RangeCheckSingleSignal(32,(2**32 - 1),0);
    customRangeCheck_UtxoOutCreateTime.in <== utxoOutCreateTime;

    // utxoOutAmount - 64 bits
    // circom supported bits - 2**64
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_UtxoOutAmount = RangeCheckGroupOfSignals(2, 64,(2**64 - 1),0);
    customRangeCheck_UtxoOutAmount.in <== utxoOutAmount;

    // utxoOutOriginNetworkId - 6 bits
    // circom supported bits - 2**6
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_UtxoOutOriginNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0);
    customRangeCheck_UtxoOutOriginNetworkId.in <== utxoOutOriginNetworkId;

    // utxoOutTargetNetworkId - 6 bit
    // circom supported bits - 2**6
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_UtxoOutTargetNetworkId = RangeCheckGroupOfSignals(2, 6,(2**6 - 1),0);
    customRangeCheck_UtxoOutTargetNetworkId.in <== utxoOutTargetNetworkId;

    // utxoOutTargetZoneId - 16 bits
    // circom supported bits - 2**16
    // Supported range - [0 to (2**16 - 1)]
    component customRangeCheck_UtxoOutTargetZoneId = RangeCheckGroupOfSignals(2, 16,(2**16 - 1),0);
    customRangeCheck_UtxoOutTargetZoneId.in <== utxoOutTargetZoneId;

    // utxoOutTargetZoneIdOffset - 4 bits
    // circom supported bits - 2**4
    // Supported range - [0 to (2**4 - 1)]
    component customRangeCheck_UtxoOutTargetZoneIdOffset = RangeCheckGroupOfSignals(2, 4,(2**4 - 1),0);
    customRangeCheck_UtxoOutTargetZoneIdOffset.in <== utxoOutTargetZoneIdOffset;

    // utxoOutSpendPubKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // utxoOutRootSpendPubKey - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // utxoOutCommitment
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zAccountUtxoOutZkpAmount - 252 bits
    // Supported range - [0 to (2**252 - 1)]
    // Public signal - Checked as part of Smart Contract
    component customRangeCheck_ZAccountUtxoOutZkpAmount = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ZAccountUtxoOutZkpAmount.in <== zAccountUtxoOutZkpAmount;

    // zAccountUtxoOutSpendKeyRandom - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zAccountUtxoOutCommitment
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // chargedAmountZkp - 256 bits
    // Public signal
    // Should be checked as part of the SC
    component customRangeCheck_ChargedAmountZkp = RangeCheckSingleSignal(252,(2**252 - 1),0);
    customRangeCheck_ChargedAmountZkp.in <== chargedAmountZkp;

    // zNetworkId - 6 bits
    // Supported range - [0 to (2**6 - 1)]
    component customRangeCheck_ZNetworkId = RangeCheckSingleSignal(6,(2**6 - 1),0);
    customRangeCheck_ZNetworkId.in <== zNetworkId;

    // zNetworkChainId - 256 bits
    // Public signal
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // zNetworkIDsBitMap - 64 bits
    // Supported range - [0 to (2**64 - 1)]
    component customRangeCheck_ZNetworkIDsBitMap = RangeCheckSingleSignal(64,(2**64 - 1),0);
    customRangeCheck_ZNetworkIDsBitMap.in <== zNetworkIDsBitMap;

    // zNetworkTreeMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkTreePathElements
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // zNetworkTreePathIndices - 256 bits
    // ToDo - Must be restricted to binary?
    // component customRangeCheck_ZNetworkTreePathIndices = RangeCheckGroupOfSignals(6, 252,(2**252 - 1),0);
    // customRangeCheck_ZNetworkTreePathIndices.in <== zNetworkTreePathIndices;

    // staticTreeMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // forestMerkleRoot
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // taxiMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // busMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // ferryMerkleRoot
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // salt - 256 bits
    // Range checking tool in circom supports only till 252 bits, hence it can't be checked here
    // Should be checked as part of the SC

    // saltHash
    // Public signal
    // Must be within the SNARK_FIELD
    // Should be checked as part of the SC

    // magicalConstraint - 256 bits
    // Public signal
    // Should be checked as part of the SC
}
