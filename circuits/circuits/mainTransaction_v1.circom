//SPDX-License-Identifier: ISC
pragma circom 2.0.0;
include "./transaction_v1.circom";

// nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth
component main {public [publicInputsHash]} = TransactionV1(2,2,16,6);
