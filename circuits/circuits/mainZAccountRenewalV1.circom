// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./zAccountRenewalV1Top.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        addedAmountZkp,                        // [2]
        chargedAmountZkp,                      // [3]
        zAccountUtxoInNullifier,               // [4]
        zAccountUtxoOutCommitment,             // [5]
        zAccountUtxoOutCreateTime,             // [6]
        kycSignedMessageHash,                  // [7]
        staticTreeMerkleRoot,                  // [8]
        forestMerkleRoot,                      // [9]
        saltHash,                              // [10]
        magicalConstraint                      // [11]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 11
    ]} = ZAccountRenewalV1Top( 8,     // UtxoLeftMerkleTreeDepth
                               26,    // UtxoMiddleMerkleTreeDepth
                               6,     // ZNetworkMerkleTreeDepth
                               16,    // ZAssetMerkleTreeDepth
                               16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                               16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                               16,    // TrustProvidersMerkleTreeDepth
                               0 );   // IsTestNet - for production it should be `1`
