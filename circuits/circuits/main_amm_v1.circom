//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./amm_v1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        chargedAmountZkp,                      // [2]
        createTime,                            // [3]
        depositAmountPrp,                      // [4]
        withdrawAmountPrp,                     // [5]
        utxoCommitment,                        // [6]
        utxoSpendPubKey,                       // [7] - x,y
        zAssetScale,                           // [8]
        zAccountUtxoInNullifier,               // [9]
        zAccountUtxoOutCommitment,             // [10]
        zNetworkChainId,                       // [11]
        forestMerkleRoot,                      // [12]
        saltHash,                              // [13]
        magicalConstraint                      // [14]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 13 + 2 = 15
    ]} = AmmV1 ( 6,     // UtxoLeftMerkleTreeDepth
                 26,    // UtxoMiddleMerkleTreeDepth
                 6,     // ZNetworkMerkleTreeDepth
                 16,    // ZAssetMerkleTreeDepth
                 16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                 16 );  // ZZoneMerkleTreeDepth - depends on zoneID size
