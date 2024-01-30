// SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../../node_modules/circomlib/circuits/bitify.circom";

template ZAccountLeafDecoder(UtxoMerkleTreeDepth){

  signal input leaves[2];
  // first leaf - included in preimage
  signal output id;                             // 24 bit
  signal output amountZkp;                      // 64 bit
  signal output amountPrp;                      // 64 bit
  signal output zoneId;                         // 16 bit
  signal output expiryTime;                     // 32 bit
  signal output nonce;                          // 16 bit
  // second leaf - not included in preimage
  signal output treeNumber;                     // 24 bit
  signal output index[UtxoMerkleTreeDepth+1];   // 16 bit

  assert(UtxoMerkleTreeDepth <= 16);
  ///////////////////////////////////////////////////////////
  // [0] - First leaf
  ///////////////////////////////////////////////////////////
  component n2b_0 = Num2Bits(216);
  n2b_0.in <== leaves[0];
  var shift = 216;

  component b2nId = Bits2Num(24);
  shift -= 24;
  for (var i = 0; i < 24; i++) {
      b2nId.in[i] <== n2b_0.out[shift+i]; // 216 - 24 + 0..23
  }
  id <== b2nId.out;

  component b2nAmountZkp = Bits2Num(64);
  shift -= 64;
  for (var i = 0; i < 64; i++) {
      b2nAmountZkp.in[i] <== n2b_0.out[shift+i];
  }
  amountZkp <== b2nAmountZkp.out;

  component b2nAmountPrp = Bits2Num(64);
  shift -= 64;
  for (var i = 0; i < 64; i++) {
      b2nAmountPrp.in[i] <== n2b_0.out[shift+i];
  }
  amountPrp <== b2nAmountPrp.out;

  component b2nZoneId = Bits2Num(16);
  shift -= 16;
  for (var i = 0; i < 16; i++) {
      b2nZoneId.in[i] <== n2b_0.out[shift+i];
  }
  zoneId <== b2nZoneId.out;

  component b2nExpiryTime = Bits2Num(32);
  shift -= 32;
  for (var i = 0; i < 32; i++) {
      b2nExpiryTime.in[i] <== n2b_0.out[shift+i];
  }
  expiryTime <== b2nExpiryTime.out;

  component b2nNonce = Bits2Num(16);
  shift -= 16;
  for (var i = 0; i < 16; i++) {
      b2nNonce.in[i] <== n2b_0.out[shift+i];
  }
  nonce <== b2nNonce.out;

  ///////////////////////////////////////////////////////////
  // [1] - Second leaf
  ///////////////////////////////////////////////////////////
  component n2b_1 = Num2Bits(24+UtxoMerkleTreeDepth+1);
  n2b_1.in <== leaves[1];
  shift = 24 + UtxoMerkleTreeDepth + 1;

  component b2nTree = Bits2Num(24);
  shift -= 24;
  for (var i = 0; i < 24; i++) {
      b2nTree.in[i] <== n2b_1.out[shift+i];
  }
  treeNumber <== b2nTree.out;

  component b2nIndex = Bits2Num(UtxoMerkleTreeDepth+1);

  shift -= (UtxoMerkleTreeDepth+1);
  for (var i = 0; i < UtxoMerkleTreeDepth+1; i++) {
      index[i] <== n2b_1.out[shift+i];
  }
}
