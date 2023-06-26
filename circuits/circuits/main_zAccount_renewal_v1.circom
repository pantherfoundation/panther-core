//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./zAccount_renewal_v1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        zAccountUtxoInNullifier,               // [2]
        zAccountUtxoOutCommitment,             // [3]
        zAccountUtxoOutCreateTime,             // [4]
        kycSignedMessageHash,                  // [5]
        forestMerkleRoot,                      // [6]
        saltHash,                              // [7]
        magicalConstraint                      // [8]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 8
    ]} = ZAccountRenewalV1( 6,     // ZNetworkMerkleTreeDepth
                            16,    // ZAssetMerkleTreeDepth
                            16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                            16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                            16 );  // KycKytMerkleTreeDepth
