//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./zSwapV1Top.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        depositAmount,                         // [2]
        withdrawAmount,                        // [3]
        addedAmountZkp,                        // [4]
        token,                                 // [5] - can be 1 or 2
        tokenId,                               // [6] - can be 1 or 2
        zAssetScale,                           // [7] - can be 2 or 3
        spendTime,                             // [8]
        utxoInNullifier,                       // [9] - nUtxoIn = 2
        zAccountUtxoInNullifier,               // [10]
        zZoneDataEscrowEphemeralPubKeyAx,      // [11] - 1 (NOTE: only x-coordinate)
        zZoneDataEscrowEncryptedMessageAx,     // [12] - 1 (NOTE: only x-coordinate)
        kytDepositSignedMessageSender,         // [13]
        kytDepositSignedMessageReceiver,       // [14]
        kytDepositSignedMessageHash,           // [15]
        kytWithdrawSignedMessageSender,        // [16]
        kytWithdrawSignedMessageReceiver,      // [17]
        kytWithdrawSignedMessageHash,          // [18]
        kytSignedMessageHash,                  // [19]
        dataEscrowEncryptedMessageAx,          // [20] - 11 (NOTE: only x-coordinate)
        daoDataEscrowEphemeralPubKeyAx,        // [21] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessageAx,       // [22] - 1 (NOTE: only x-coordinate)
        utxoOutCreateTime,                     // [23]
        utxoOutCommitment,                     // [24] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [25]
        chargedAmountZkp,                      // [26]
        zNetworkChainId,                       // [27]
        staticTreeMerkleRoot,                  // [28]
        forestMerkleRoot,                      // [29]
        saltHash,                              // [30]
        magicalConstraint                      // [31]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 31 + 1 + 1 + 2 + 1 + 10 + 1 = 47
    ]} = ZSwapV1Top( 2,     // nUtxoIn
                     2,     // nUtxoOut
                     8,     // UtxoLeftMerkleTreeDepth
                     26,    // UtxoMiddleMerkleTreeDepth
                     6,     // ZNetworkMerkleTreeDepth
                     16,    // ZAssetMerkleTreeDepth
                     16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                     16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                     16,    // TrustProvidersMerkleTreeDepth
                     1 );   // is zSwap { 0,1 }
