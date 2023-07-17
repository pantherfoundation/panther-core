//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./zAccount_renewal_v1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        chargedAmountZkp,                      // [2]
        zAccountUtxoInNullifier,               // [3]
        zAccountUtxoOutCommitment,             // [4]
        zAccountUtxoOutCreateTime,             // [5]
        kycSignedMessageHash,                  // [6]
        forestMerkleRoot,                      // [7]
        saltHash,                              // [8]
        magicalConstraint                      // [9]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 9
    ]} = ZAccountRenewalV1( 6,     // ZNetworkMerkleTreeDepth
                            16,    // ZAssetMerkleTreeDepth
                            16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                            16,    // ZZoneMerkleTreeDepth - depends on zoneID size
                            16 );  // KycKytMerkleTreeDepth
