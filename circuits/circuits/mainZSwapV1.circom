//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./zSwapV1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        depositAmount,                         // [2]
        withdrawAmount,                        // [3]
        token,                                 // [4] - can be 1 or 2
        tokenId,                               // [5] - can be 1 or 2
        spendTime,                             // [6]
        utxoInNullifier,                       // [7] - nUtxoIn = 2
        zAccountUtxoInNullifier,               // [8]
        zZoneDataEscrowEphimeralPubKeyAx,      // [9] - 1 (NOTE: only x-coordinate)
        zZoneDataEscrowEncryptedMessageAx,     // [10] - 1 (NOTE: only x-coordinate)
        kytDepositSignedMessageSender,         // [11]
        kytDepositSignedMessageReceiver,       // [12]
        kytDepositSignedMessageHash,           // [13]
        kytWithdrawSignedMessageSender,        // [14]
        kytWithdrawSignedMessageReceiver,      // [15]
        kytWithdrawSignedMessageHash,          // [16]
        dataEscrowEphimeralPubKeyAx,           // [17] - 1 (NOTE: only x-coordinate)
        dataEscrowEncryptedMessageAx,          // [18] - 1 + 1 + nUtxoIn + nUtxoOut + MAX(nUtxoIn,nUtxoOut) = 8 (NOTE: only x-coordinate)
        daoDataEscrowEphimeralPubKeyAx,        // [19] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessageAx,       // [20] - 1 + MAX(nUtxoIn,nUtxoOut) = 3 (NOTE: only x-coordinate)
        utxoOutCreateTime,                     // [21]
        utxoOutCommitment,                     // [22] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [23]
        chargedAmountZkp,                      // [24]
        zNetworkChainId,                       // [25]
        forestMerkleRoot,                      // [26]
        saltHash,                              // [27]
        magicalConstraint                      // [28]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 30 + 1 + 7 + 2 + 1 = 41
    ]} = ZSwapV1( 2,     // nUtxoIn
                  2,     // nUtxoOut
                  6,     // UtxoLeftMerkleTreeDepth
                  26,    // UtxoMiddleMerkleTreeDepth
                  6,     // ZNetworkMerkleTreeDepth
                  16,    // ZAssetMerkleTreeDepth
                  16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                  16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                  16,    // TrustProvidersMerkleTreeDepth
                  1 );   // is zSwap { 0,1 }
