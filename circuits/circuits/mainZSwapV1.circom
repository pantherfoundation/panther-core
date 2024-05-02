//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./zSwapV1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        depositAmount,                         // [2]
        withdrawAmount,                        // [3]
        addedAmountZkp,                        // [4]
        token,                                 // [5] - can be 1 or 2
        tokenId,                               // [6] - can be 1 or 2
        zAssetScale,                           // [7] - can be 1 or 2
        spendTime,                             // [8]
        utxoInNullifier,                       // [9] - nUtxoIn = 2
        zAccountUtxoInNullifier,               // [10]
        zZoneDataEscrowEphimeralPubKeyAx,      // [11] - 1 (NOTE: only x-coordinate)
        zZoneDataEscrowEncryptedMessageAx,     // [12] - 1 (NOTE: only x-coordinate)
        kytDepositSignedMessageSender,         // [13]
        kytDepositSignedMessageReceiver,       // [14]
        kytDepositSignedMessageHash,           // [15]
        kytWithdrawSignedMessageSender,        // [16]
        kytWithdrawSignedMessageReceiver,      // [17]
        kytWithdrawSignedMessageHash,          // [18]
        dataEscrowEphimeralPubKeyAx,           // [19] - 1 (NOTE: only x-coordinate)
        dataEscrowEncryptedMessageAx,          // [20] - 1 + 1 + nUtxoIn + nUtxoOut + MAX(nUtxoIn,nUtxoOut) = 8 (NOTE: only x-coordinate)
        daoDataEscrowEphimeralPubKeyAx,        // [21] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessageAx,       // [22] - 1 + MAX(nUtxoIn,nUtxoOut) = 3 (NOTE: only x-coordinate)
        utxoOutCreateTime,                     // [23]
        utxoOutCommitment,                     // [24] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [25]
        chargedAmountZkp,                      // [26]
        zNetworkChainId,                       // [27]
        staticTreeMerkleRoot,                  // [28]
        forestMerkleRoot,                      // [29]
        saltHash,                              // [30]
        magicalConstraint                      // [31]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 31 + 1 + 1 + 1 + 1 + 8 + 3 + 1 = 48
    ]} = ZSwapV1( 2,     // nUtxoIn
                  2,     // nUtxoOut
                  8,     // UtxoLeftMerkleTreeDepth
                  26,    // UtxoMiddleMerkleTreeDepth
                  6,     // ZNetworkMerkleTreeDepth
                  16,    // ZAssetMerkleTreeDepth
                  16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                  16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                  16,    // TrustProvidersMerkleTreeDepth
                  1 );   // is zSwap { 0,1 }
