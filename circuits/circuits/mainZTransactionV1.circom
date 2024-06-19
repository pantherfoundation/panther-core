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
        kytSignedMessageHash,                  // [18]
        dataEscrowEncryptedMessageAx,          // [19] - 1 + 1 + nUtxoIn + nUtxoOut + MAX(nUtxoIn,nUtxoOut) = 8 (NOTE: only x-coordinate)
        daoDataEscrowEphemeralPubKeyAx,        // [20] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessageAx,       // [21] - 1 (NOTE: only x-coordinate)
        utxoOutCreateTime,                     // [22]
        utxoOutCommitment,                     // [23] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [24]
        chargedAmountZkp,                      // [25]
        zNetworkChainId,                       // [26]
        staticTreeMerkleRoot,                  // [27]
        forestMerkleRoot,                      // [28]
        saltHash,                              // [29]
        magicalConstraint                      // [30]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 30 + ... = 41
    ]} = ZTransactionV1 ( 2,     // nUtxoIn
                          2,     // nUtxoOut
                          8,     // UtxoLeftMerkleTreeDepth
                          26,    // UtxoMiddleMerkleTreeDepth
                          6,     // ZNetworkMerkleTreeDepth
                          16,    // ZAssetMerkleTreeDepth
                          16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                          16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                          16 );  // TrustProvidersMerkleTreeDepth
