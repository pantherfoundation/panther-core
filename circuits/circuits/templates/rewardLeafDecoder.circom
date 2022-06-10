//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/bitify.circom";


template RewardLeafDecoder(UtxoMerkleTreeDepth){
  signal input leaf;
  signal output amount;
  signal output treeNumber;
  signal output index[UtxoMerkleTreeDepth+1];
  // 120 bits for amount
  //   8 bits for treeNumber
  //  depth bits for index
  assert(UtxoMerkleTreeDepth <= 16);

  component n2b = Num2Bits(160+UtxoMerkleTreeDepth);
  n2b.in <== leaf;

  component b2nAmount = Bits2Num(120);
  for(var i=0; i<120; i++)
      b2nAmount.in[i] <== n2b.out[i];
  amount <== b2nAmount.out;

  var shift = 120;
  component b2nTree = Bits2Num(8);
  for(var i=0; i<8; i++)
      b2nTree.in[i] <== n2b.out[shift+i];
  treeNumber <== b2nTree.out;

  shift = shift + 8;
  component b2nIndex = Bits2Num(UtxoMerkleTreeDepth);
  for(var i=0; i<UtxoMerkleTreeDepth; i++)
      index[i] <== n2b.out[shift+i];
}
