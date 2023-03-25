//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./transaction_v1_extended.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        depositAmount,                         // [2]
        depositChange,                         // [3]
        withdrawAmount,                        // [4]
        withdrawChange,                        // [5]
        token,                                 // [6]
        tokenId,                               // [7]
        spendTime,                             // [8]
        utxoInNullifier,                       // [9] - nUtxoIn = 2
        zAccountUtxoInNullifier,               // [10]
        zZoneDataEscrowEphimeralPubKeyAx,      // [11] - 1 (NOTE: only x-coordinate)
        zZoneDataEscrowEncryptedMessageAx,     // [12] - 1 (NOTE: only x-coordinate)
        kytDepositSignedMessageHash,           // [13]
        kytWithdrawSignedMessageHash,          // [14]
        dataEscrowEphimeralPubKeyAx,           // [15] - 1 (NOTE: only x-coordinate)
        dataEscrowEncryptedMessageAx,          // [16] - 1 + 1 + nUtxoIn + nUtxoOut + MAX(nUtxoIn,nUtxoOut) = 8 (NOTE: only x-coordinate)
        daoDataEscrowEphimeralPubKeyAx,        // [17] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessageAx,       // [18] - 1 + MAX(nUtxoIn,nUtxoOut) = 3 (NOTE: only x-coordinate)
        utxoOutCreateTime,                     // [19]
        utxoOutCommitment,                     // [20] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [20]
        chargedAmountZkp,                      // [21]
        zNetworkChainId,                       // [22]
        forestMerkleRoot,                      // [23]
        saltHash,                              // [24]
        magicalConstraint                      // [25]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 25 + 1 + 7 + 2 + 1 = 36
    ]} = TransactionV1Extended( 2,     // nUtxoIn
                                2,     // nUtxoOut
                                6,     // UtxoLeftMerkleTreeDepth
                                26,    // UtxoMiddleMerkleTreeDepth
                                6,     // ZNetworkMerkleTreeDepth
                                16,    // ZAssetMerkleTreeDepth
                                16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                                16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                                16 );  // KycKytMerkleTreeDepth
