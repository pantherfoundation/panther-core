//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

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
        zZoneDataEscrowEncryptedMessage,       // [11]
        zZoneDataEscrowEncryptedMessageHmac,   // [12]
        kytDepositSignedMessageSender,         // [13]
        kytDepositSignedMessageReceiver,       // [14]
        kytDepositSignedMessageHash,           // [15]
        kytWithdrawSignedMessageSender,        // [16]
        kytWithdrawSignedMessageReceiver,      // [17]
        kytWithdrawSignedMessageHash,          // [18]
        kytSignedMessageHash,                  // [19]
        dataEscrowEncryptedMessage,            // [20]
        dataEscrowEncryptedMessageHmac,        // [21]
        daoDataEscrowEphemeralPubKeyAx,        // [22] - 1 (NOTE: only x-coordinate)
        daoDataEscrowEncryptedMessage,         // [23]
        daoDataEscrowEncryptedMessageHmac,     // [24]
        utxoOutCreateTime,                     // [25]
        utxoOutCommitment,                     // [26] - nUtxoOut = 2
        zAccountUtxoOutCommitment,             // [27]
        chargedAmountZkp,                      // [28]
        zNetworkChainId,                       // [29]
        staticTreeMerkleRoot,                  // [30]
        forestMerkleRoot,                      // [31]
        saltHash,                              // [32]
        magicalConstraint                      // [33]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 39
    ]} = ZTransactionV1 ( 2,     // nUtxoIn
                          2,     // nUtxoOut
                          8,     // UtxoLeftMerkleTreeDepth
                          26,    // UtxoMiddleMerkleTreeDepth
                          6,     // ZNetworkMerkleTreeDepth
                          16,    // ZAssetMerkleTreeDepth
                          16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                          16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                          16,    // TrustProvidersMerkleTreeDepth
                          1 );   // IsTestNet - for production should be `1`
