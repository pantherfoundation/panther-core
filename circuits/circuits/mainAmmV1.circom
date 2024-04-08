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
        utxoSpendPubKey,                       // [8] - x,y
        zAssetScale,                           // [9]
        zAccountUtxoInNullifier,               // [10]
        zAccountUtxoOutCommitment,             // [11]
        zNetworkChainId,                       // [12]
        staticTreeMerkleRoot,                  // [13]
        forestMerkleRoot,                      // [14]
        saltHash,                              // [15]
        magicalConstraint                      // [16]
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ // TOTAL: 16 + 1 = 17
    ]} = AmmV1 ( 8,     // UtxoLeftMerkleTreeDepth
                 26,    // UtxoMiddleMerkleTreeDepth
                 6,     // ZNetworkMerkleTreeDepth
                 16,    // ZAssetMerkleTreeDepth
                 16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                 16 );  // ZZoneMerkleTreeDepth - depends on zoneID size
