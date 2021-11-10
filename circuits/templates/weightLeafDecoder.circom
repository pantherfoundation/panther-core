//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";


template WeightLeafDecoder(WeightMerkleTreeDepth){
  signal input leaf;
  signal output token;
  signal output weight;
  signal output index[WeightMerkleTreeDepth];
  // 160 bits for token
  //  32 bits for weight
  //  depth bits (maximum 8 bits) for leafIndex
  assert(WeightMerkleTreeDepth <= 8);

  component n2b = Num2Bits(192+WeightMerkleTreeDepth);
  n2b.in <== leaf;
  
  component b2nToken = Bits2Num(160);
  for(var i=0; i<160; i++)
      b2nToken.in[i] <== n2b.out[i];
  token <== b2nToken.out;

  var shift = 160;
  component b2nWeight = Bits2Num(32);
  for(var i=0; i<32; i++)
      b2nWeight.in[i] <== n2b.out[shift+i];
  weight <== b2nWeight.out;

  shift = shift + 32;
  component b2nIndex = Bits2Num(WeightMerkleTreeDepth);
  for(var i=0; i<WeightMerkleTreeDepth; i++)
      index[i] <== n2b.out[shift+i];
}
