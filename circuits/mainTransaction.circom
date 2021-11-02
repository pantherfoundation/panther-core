//SPDX-License-Identifier: ISC
pragma circom 2.0.0;
include "./transaction.circom";

// nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth
component main {public [publicInputsHash]} = Transaction(3,3,15,6);
