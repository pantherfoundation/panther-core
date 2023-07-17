//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

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

template UtxoLeafDecoderExtended(UtxoMerkleTreeDepth){
  signal input leaf; /// we must make leaf uniq - so no collision will happen
  signal output amount;
  signal output originZoneId;
  signal output targetZoneId;
  signal output networkId;
  signal output createTime;
  signal output treeNumber;
  signal output index[UtxoMerkleTreeDepth+1];

  assert(UtxoMerkleTreeDepth <= 16);

  // 64 bits for amount
  // 16 bits for origin-zone-id
  // 16 bits for target-zone-id
  // 64 bits for networkId
  // 32 bits for createTime
  // 24 bits for treeNumber
  // depth bits for index
  component n2b = Num2Bits(64+16+16+64+32+24+UtxoMerkleTreeDepth+1);
  n2b.in <== leaf;

  component b2nAmount = Bits2Num(64);
  var shift = 0;
  for(var i=0; i<64; i++)
      b2nAmount.in[i] <== n2b.out[i];
  amount <== b2nAmount.out;

  component b2nOriginZoneId = Bits2Num(16);
  shift += 64;
  for(var i=0; i<16; i++)
      b2nOriginZoneId.in[i] <== n2b.out[shift+i];
  originZoneId <== b2nOriginZoneId.out;

  component b2nTargetZoneId = Bits2Num(16);
  shift += 16;
  for(var i=0; i<16; i++)
      b2nTargetZoneId.in[i] <== n2b.out[shift+i];
  targetZoneId <== b2nTargetZoneId.out;

  component b2nNetworkId = Bits2Num(64);
  shift += 16;
  for(var i=0; i<64; i++)
      b2nNetworkId.in[i] <== n2b.out[shift+i];
  networkId <== b2nNetworkId.out;

  component b2nCreateTime = Bits2Num(32);
  shift += 64;
  for(var i=0; i<32; i++)
      b2nCreateTime.in[i] <== n2b.out[shift+i];
  createTime <== b2nCreateTime.out;

  component b2nTree = Bits2Num(24);
  shift += 32;
  for(var i=0; i<24; i++)
      b2nTree.in[i] <== n2b.out[shift+i];
  treeNumber <== b2nTree.out;

  component b2nIndex = Bits2Num(UtxoMerkleTreeDepth+1);
  shift += 24;
  for(var i=0; i<UtxoMerkleTreeDepth+1; i++)
      index[i] <== n2b.out[shift+i];
}
