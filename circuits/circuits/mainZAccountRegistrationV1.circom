//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./zAccountRegistrationV1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        zkpAmount,                             // [2]
        zkpChange,                             // [3]
        zAccountId,                            // [4]
        zAccountPrpAmount,                     // [5]
        zAccountCreateTime,                    // [6]
        zAccountRootSpendPubKey,               // [7] - x,y = 2
        zAccountReadPubKey,                    // [8] - x,y = 2
        zAccountNullifierPubKey,               // [9] - x,y = 2
        zAccountMasterEOA,                     // [10]
        zAccountNullifier,                     // [11]
        zAccountCommitment,                    // [12]
        kycSignedMessageHash,                  // [13]
        forestMerkleRoot,                      // [14]
        saltHash,                              // [15]
        magicalConstraint                      // [16]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 16 + 3 = 19
    ]} = ZAccountRegitrationV1( 6,     // ZNetworkMerkleTreeDepth
                                16,    // ZAssetMerkleTreeDepth
                                16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                                16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                                16 );  // TrustProvidersMerkleTreeDepth
