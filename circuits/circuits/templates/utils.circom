//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Range-Check signals tags //////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// [1] - `public-tag` - public signal, checked by smart-contracts
// [2] - `anchored-tag` - signal is part of preimage that is publicly known and checked by smart-contracts (maybe not directly)
// [3] - `range-check-tag` - signal needs to be range-checked
// [4] - `assumed-tag` - signal needs to be constraint somewhere in the code
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// this index exists for zSwap & zTransaction
function TransactedTokenIndex() {
    return 0;
}

// this index exists only for zSwap
function SwapTokenIndex() {
    return 1;
}

// this index exists for zSwap & zTransaction cases but its different for each one
// since for zSwap case, `TokenArray` is extended with SwapToken
function ZkpTokenIndex( isSwap ) {
    assert(0 <= isSwap < 2);
    if ( isSwap ) {
        return 2;
    } else {
        return 1;
    }
}

// this array includes:
// 1. zSwap case: transacted & swap tokens
// 2. zTransaction case: single token
function TokenArraySize( isSwap ) {
    assert(0 <= isSwap < 2);
    if ( isSwap ) {
        return 2;
    } else {
        return 1;
    }
}

// this array includes zAsset preimages of
// 1. zSwap case: transacted-token, swap-token, zkp-token
// 2. zTransaction case: transacted-token, zkp-token
function ZAssetArraySize( isSwap ) {
    assert(0 <= isSwap < 2);
    var size = TokenArraySize( isSwap ) + 1;
    return size;
}

// Ferry MT size
function UtxoRightMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth ) {
    return  UtxoMiddleMerkleTreeDepth + ZNetworkMerkleTreeDepth;
}
// Equal to ferry MT size
function UtxoMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth ) {
    return UtxoRightMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth );
}
// Bus MT extra levels
function UtxoMiddleExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, UtxoLeftMerkleTreeDepth ) {
    return UtxoMiddleMerkleTreeDepth - UtxoLeftMerkleTreeDepth;
}
// Ferry MT extra levels
function UtxoRightExtraLevels_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth ) {
    return  UtxoRightMerkleTreeDepth_Fn( UtxoMiddleMerkleTreeDepth, ZNetworkMerkleTreeDepth ) - UtxoMiddleMerkleTreeDepth;
}

function MaxUtxoInOut_Fn(nUtxoIn, nUtxoOut) {
    return  nUtxoIn > nUtxoOut ? nUtxoIn : nUtxoOut;
}

// the only point in the zZone data-escrow is the ephemeral pub-key of the main data-escrow safe
function ZZoneDataEscrowPoints_Fn() {
    return 1;
}

function ZZoneDataEscrowEncryptedPoints_Fn() {
    return ZZoneDataEscrowPoints_Fn();
}

// ------------- scalars-size --------------------------------
// 1) 1 x 64 (zAsset)
// 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
// 3) nUtxoIn x 64 amount
// 4) nUtxoOut x 64 amount
// 5) MAX(nUtxoIn,nUtxoOut) x ( , utxoInPathIndices[..] << 32 bit | utxo-in-origin-zones-ids << 16 | utxo-out-target-zone-ids << 0 )
function DataEscrowScalarSize_Fn( nUtxoIn, nUtxoOut ) {
    var dataEscrowScalarSize =  1 + 1 + nUtxoIn + nUtxoOut + MaxUtxoInOut_Fn(nUtxoIn,nUtxoOut);
    return dataEscrowScalarSize;
}
// ------------- ec-points-size -------------
// 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)
function DataEscrowPointSize_Fn( nUtxoOut ) {
    return nUtxoOut;
}

function DataEscrowEncryptedPoints_Fn( nUtxoIn, nUtxoOut ) {
    return DataEscrowScalarSize_Fn( nUtxoIn, nUtxoOut ) + DataEscrowPointSize_Fn( nUtxoOut );
}

// the only point in the zZone data-escrow is the ephemeral pub-key of the main data-escrow safe
function DaoDataEscrowPoints_Fn() {
    return 1;
}

function DaoDataEscrowEncryptedPoints_Fn() {
    return DaoDataEscrowPoints_Fn();
}

template SafePositiveMultiplier( isPositiveCheckRequiredForFirstSignal,
                                 firstSignalUpperBound,
                                 isPositiveCheckRequiredForSecondSignal,
                                 secondSignalUpperBound) {
    signal input in[2];
    signal output out;
    // this requirement insure a possibility of an overflow
    assert(firstSignalUpperBound + secondSignalUpperBound < 252);

    component rc[2];
    if( isPositiveCheckRequiredForFirstSignal ) {
        rc[0] = LessEqThan(firstSignalUpperBound);
        rc[0].in[0] <== in[0];
        rc[0].in[1] <== 2**firstSignalUpperBound;
        rc[0].out === 1;
    }
    if( isPositiveCheckRequiredForSecondSignal ) {
        rc[0] = LessEqThan(secondSignalUpperBound);
        rc[0].in[0] <== in[1];
        rc[0].in[1] <== 2**secondSignalUpperBound;
        rc[0].out === 1;
    }
    out <== in[0] * in[1];
}

template Globals() {
    signal output true <== 1;
    signal output false <== 0;
}

template BinaryRangeCheck() {
    signal input in;
    in - in * in === 0;
}

template LessThanBits(nBits) {
    signal input in;

    // "positive" input assumed
    assert(nBits < 252);

    component lessThan = LessThan(nBits);
    lessThan.in[0] <== in;
    lessThan.in[1] <== 2**nBits;

    // force
    lessThan.out === 1;
}
