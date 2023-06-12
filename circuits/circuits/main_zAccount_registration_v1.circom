//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./zAccount_registration_v1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        zkpAmount,                             // [2]
        zkpChange,                             // [3]
        zAccountId,                            // [4]
        zAccountPrpAmount,                     // [5]
        zAccountRootSpendPubKey,               // [6] - x,y = 2
        zAccountMasterEOA,                     // [7]
        zAccountNullifier,                     // [8]
        zAccountCommitment,                    // [9]
        kycSignedMessageHash,                  // [10]
        forestMerkleRoot,                      // [11]
        saltHash,                              // [12]
        magicalConstraint                      // [13]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 11 + 2 = 13
    ]} = ZAccountRegitrationV1( 6,     // ZNetworkMerkleTreeDepth
                                16,    // ZAssetMerkleTreeDepth
                                16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                                16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                                16 );  // KycKytMerkleTreeDepth
