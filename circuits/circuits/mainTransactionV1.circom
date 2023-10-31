//SPDX-License-Identifier: ISC
pragma circom 2.1.6;
include "./transaction_v1.circom";

// nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth
component main {public [publicInputsHash]} = TransactionV1(2,2,16,6);
