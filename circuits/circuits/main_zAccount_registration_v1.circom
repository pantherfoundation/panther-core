//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./zAccount_registration_v1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        zkpAmount,                             // [2]
        zkpChange,                             // [3]
        zAccountId,                            // [4]
        zAccountPrpAmount,                     // [5]
        zAccountCreateTime,                    // [6]
        zAccountRootSpendPubKey,               // [7] - x,y = 2
        zAccountMasterEOA,                     // [8]
        zAccountNullifier,                     // [9]
        zAccountCommitment,                    // [10]
        kycSignedMessageHash,                  // [11]
        forestMerkleRoot,                      // [12]
        saltHash,                              // [13]
        magicalConstraint                      // [14]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 13 + 2 = 15
    ]} = ZAccountRegitrationV1( 6,     // ZNetworkMerkleTreeDepth
                                16,    // ZAssetMerkleTreeDepth
                                16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                                16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                                16 );  // KycKytMerkleTreeDepth
