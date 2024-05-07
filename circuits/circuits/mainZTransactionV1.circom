//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./zTransactionV1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        depositAmount,                         // [2]
        withdrawAmount,                        // [3]
        addedAmountZkp,                        // [4]
        token,                                 // [5]
        tokenId,                               // [6]
        spendTime,                             // [7]
        utxoInNullifier,                       // [8] - nUtxoIn = 2
        zAccountUtxoInNullifier,               // [9]
        zZoneDataEscrowEphemeralPubKeyAx,      // [10] - 1 (NOTE: only x-coordinate)
        zZoneDataEscrowEncryptedMessageAx,     // [11] - 1 (NOTE: only x-coordinate)
        kytDepositSignedMessageSender,         // [12]
        kytDepositSignedMessageReceiver,       // [13]
        kytDepositSignedMessageHash,           // [14]
        kytWithdrawSignedMessageSender,        // [15]
        kytWithdrawSignedMessageReceiver,      // [16]
        kytWithdrawSignedMessageHash,          // [17]
        dataEscrowEncryptedMessageAx,          // [18] - 1 + 1 + nUtxoIn + nUtxoOut + MAX(nUtxoIn,nUtxoOut) = 8 (NOTE: only x-coordinate)
        daoDataEscrowEphemeralPubKeyAx,        // [19] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessageAx,       // [20] - 1 + MAX(nUtxoIn,nUtxoOut) = 3 (NOTE: only x-coordinate)
        utxoOutCreateTime,                     // [21]
        utxoOutCommitment,                     // [22] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [23]
        chargedAmountZkp,                      // [24]
        zNetworkChainId,                       // [25]
        staticTreeMerkleRoot,                  // [26]
        forestMerkleRoot,                      // [27]
        saltHash,                              // [28]
        magicalConstraint                      // [29]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 29 + 1 + 7 + 2 + 1 = 41 (TODO: count is 40, but circom shows 41 - fix)
    ]} = ZTransactionV1( 2,     // nUtxoIn
                         2,     // nUtxoOut
                         8,     // UtxoLeftMerkleTreeDepth
                         26,    // UtxoMiddleMerkleTreeDepth
                         6,     // ZNetworkMerkleTreeDepth
                         16,    // ZAssetMerkleTreeDepth
                         16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                         16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                         16 );  // TrustProvidersMerkleTreeDepth
