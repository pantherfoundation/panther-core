//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./ammV1.circom";

component main {
    public [
        extraInputsHash,                       // [1]
        addedAmountZkp,                        // [2]
        chargedAmountZkp,                      // [3]
        createTime,                            // [4]
        depositAmountPrp,                      // [5]
        withdrawAmountPrp,                     // [6]
        utxoCommitment,                        // [7]
        zAssetScale,                           // [8]
        zAccountUtxoInNullifier,               // [9]
        zAccountUtxoOutCommitment,             // [10]
        zNetworkChainId,                       // [11]
        staticTreeMerkleRoot,                  // [12]
        forestMerkleRoot,                      // [13]
        saltHash,                              // [14]
        magicalConstraint                      // [15]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 15
    ]} = AmmV1 ( 8,     // UtxoLeftMerkleTreeDepth
                 26,    // UtxoMiddleMerkleTreeDepth
                 6,     // ZNetworkMerkleTreeDepth
                 16,    // ZAssetMerkleTreeDepth
                 16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                 16 );  // ZZoneMerkleTreeDepth - depends on zoneID size
