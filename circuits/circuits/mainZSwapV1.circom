// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
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
        zZoneDataEscrowEncryptedMessage,       // [12]
        zZoneDataEscrowEncryptedMessageHmac,   // [13]
        kytDepositSignedMessageSender,         // [14]
        kytDepositSignedMessageReceiver,       // [15]
        kytDepositSignedMessageHash,           // [16]
        kytWithdrawSignedMessageSender,        // [17]
        kytWithdrawSignedMessageReceiver,      // [18]
        kytWithdrawSignedMessageHash,          // [19]
        kytSignedMessageHash,                  // [20]
        dataEscrowEncryptedMessage,            // [21]
        dataEscrowEncryptedMessageHmac,        // [22]
        daoDataEscrowEphemeralPubKeyAx,        // [23] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessage,         // [24]
        daoDataEscrowEncryptedMessageHmac,     // [25]
        utxoOutCreateTime,                     // [26]
        utxoOutCommitment,                     // [27] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [28]
        chargedAmountZkp,                      // [29]
        zNetworkChainId,                       // [30]
        staticTreeMerkleRoot,                  // [31]
        forestMerkleRoot,                      // [32]
        saltHash,                              // [33]
        magicalConstraint                      // [34]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 44
    ]} = ZSwapV1Top( 2,     // nUtxoIn
                     2,     // nUtxoOut
                     8,     // UtxoLeftMerkleTreeDepth
                     26,    // UtxoMiddleMerkleTreeDepth
                     6,     // ZNetworkMerkleTreeDepth
                     16,    // ZAssetMerkleTreeDepth
                     16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                     16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                     16,    // TrustProvidersMerkleTreeDepth
                     1,     // is zSwap { 0,1 }
                     0 );   // IsTestNet - for production should be `1`
