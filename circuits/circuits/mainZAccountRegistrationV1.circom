//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./zAccountRegistrationV1Top.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        addedAmountZkp,                        // [2]
        chargedAmountZkp,                      // [3]
        zAccountId,                            // [4]
        zAccountCreateTime,                    // [5]
        zAccountRootSpendPubKey,               // [6] - x,y = 2
        zAccountReadPubKey,                    // [7] - x,y = 2
        zAccountNullifierPubKey,               // [8] - x,y = 2
        zAccountMasterEOA,                     // [9]
        zAccountNullifier,                     // [10]
        zAccountCommitment,                    // [11]
        kycSignedMessageHash,                  // [12]
        staticTreeMerkleRoot,                  // [13]
        forestMerkleRoot,                      // [14]
        saltHash,                              // [15]
        magicalConstraint                      // [16]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 16 + 3 = 19
    ]} = ZAccountRegistrationV1Top( 6,     // ZNetworkMerkleTreeDepth
                                    16,    // ZAssetMerkleTreeDepth
                                    16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                                    16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                                    16,    // TrustProvidersMerkleTreeDepth
                                    1 );   // IsTestNet - for production it should be `1`
