//SPDX-License-Identifier: ISC
pragma circom 2.1.6;
include "./transaction.circom";

// nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth
component main {public [publicInputsHash]} = Transaction(2,2,16,6);
