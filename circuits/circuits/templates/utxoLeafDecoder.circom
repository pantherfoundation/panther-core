//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/bitify.circom";


template UtxoLeafDecoder(UtxoMerkleTreeDepth){
  signal input leaf; /// we must make leaf uniq - so no collision will happen
  signal output amount;
  signal output createTime;
  signal output treeNumber;
  signal output index[UtxoMerkleTreeDepth+1];
  // 120 bits for amount
  //  32 bits for createTime
  //  24 bits for treeNumber
  //  depth bits for index
  assert(UtxoMerkleTreeDepth <= 16);

  component n2b = Num2Bits(120+32+24+UtxoMerkleTreeDepth+1);
  n2b.in <== leaf;

  component b2nAmount = Bits2Num(120);
  for(var i=0; i<120; i++)
      b2nAmount.in[i] <== n2b.out[i];
  amount <== b2nAmount.out;

  var shift = 120;
  component b2nCreate = Bits2Num(32);
  for(var i=0; i<32; i++)
      b2nCreate.in[i] <== n2b.out[shift+i];
  createTime <== b2nCreate.out;

  shift = shift + 32;
  component b2nTree = Bits2Num(24);
  for(var i=0; i<24; i++)
      b2nTree.in[i] <== n2b.out[shift+i];
  treeNumber <== b2nTree.out;

  shift = shift + 24;
  component b2nIndex = Bits2Num(UtxoMerkleTreeDepth+1);
  for(var i=0; i<UtxoMerkleTreeDepth+1; i++)
      index[i] <== n2b.out[shift+i];
}
