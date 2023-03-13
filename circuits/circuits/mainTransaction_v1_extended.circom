//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./transaction_v1_extended.circom";

// publicInputsHash is THE ONLY Explicitly PUBLIC signal ---> input to the verifier
component main {public [publicInputsHash]} = TransactionV1Extended( 2,     // nUtxoIn
                                                                    2,     // nUtxoOut
                                                                    2,     // nKytSignedMessage
                                                                    16,    // UtxoMerkleTreeDepth
                                                                    16,    // ZAssetMerkleTreeDepth
                                                                    16,    // ZAccountBlackListMerkleTreeDepth - depends on zAccountID size
                                                                    16,    // ZoneRecordsMerkleTreeDepth - depends on zoneID size
                                                                    16 );  // KycKytMerkleTreeDepth
