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
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IGNORED TAGS ////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template IgnoreTag() {
    signal input in;
    signal output {ignore} out;

    out <== in;
}

template IgnoreTagArray(N) {
    signal input in[N];
    signal output {ignore} out[N];

    out <== in;
}

template IgnoreTag2DimArray(N,M) {
    signal input in[N][M];
    signal output {ignore} out[N][M];

    out <== in;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Checked by Smart Contracts //////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template ExternalTag() {
    signal input in;
    signal output {external} out;

    out <== in;
}

template ExternalTagArray(N) {
    signal input in[N];
    signal output {external} out[N];

    out <== in;
}

template ExternalTag2DimArray(N,M) {
    signal input in[N][M];
    signal output {external} out[N][M];

    out <== in;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UINTs ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template UintTag(isActive, nBits) {
    signal input in;
    signal output {uint} out;

    assert(nBits <= 252);

    component n2b;
    if ( isActive ) {
        n2b = Num2Bits(nBits);
        n2b.in <== in;
    }
    out <== in;
}

template BinaryTag(isActive) {
    signal input in;
    signal output {binary} out;

    if ( isActive ) {
        in - in * in === 0;
    }

    out <== in;
}

template BinaryTagArray(isActive,N) {
    signal input in[N];
    signal output {binary} out[N];

    component b[N];
    if ( isActive ) {
        for(var i = 0; i < N; i++) {
            b[i] = BinaryTag(isActive);
            b[i].in <== in[i];
            out[i] <== b[i].out;
        }
    } else {
        out <== in;
    }
}

template BinaryTag2DimArray(isActive,N,M) {
    signal input in[N][M];
    signal output {binary} out[N][M];

    component b[N][M];
    if ( isActive ) {
        for(var i = 0; i < N; i++) {
            for(var j = 0; j < M; j++) {
                b[i][j] = BinaryTag(isActive);
                b[i][j].in <== in[i][j];
                out[i][j] <== b[i][j].out;
            }
        }
    } else {
        out <== in;
    }
}

template Uint2Tag(isActive) {
    signal input in;
    signal output {uint2} out;

    component p = UintTag(isActive, 2);
    p.in <== in;

    out <== p.out;
}

template BinaryZero() {
    signal output {binary} out <== 0;
}

template BinaryOne() {
    signal output {binary} out <== 1;
}

template Uint3Tag(isActive) {
    signal input in;
    signal output {uint3} out;

    component p = UintTag(isActive, 3);
    p.in <== in;

    out <== p.out;
}

template Uint4Tag(isActive) {
    signal input in;
    signal output {uint4} out;

    component p = UintTag(isActive, 4);
    p.in <== in;

    out <== p.out;
}

template Uint4TagArray(isActive,N) {
    signal input in[N];
    signal output {uint4} out[N];

    component p = UintTagArray(isActive, N, 4);
    p.in <== in;

    out <== p.out;
}

template Uint5Tag(isActive) {
    signal input in;
    signal output {uint5} out;

    component p = UintTag(isActive, 5);
    p.in <== in;

    out <== p.out;
}

template Uint6Tag(isActive) {
    signal input in;
    signal output {uint6} out;

    component p = UintTag(isActive, 6);
    p.in <== in;

    out <== p.out;
}

template Uint6TagArray(isActive,N) {
    signal input in[N];
    signal output {uint6} out[N];

    component p = UintTagArray(isActive, N, 6);
    p.in <== in;

    out <== p.out;
}

template Uint8Tag(isActive) {
    signal input in;
    signal output {uint8} out;

    component p = UintTag(isActive, 8);
    p.in <== in;

    out <== p.out;
}

template Uint16Tag(isActive) {
    signal input in;
    signal output {uint16} out;

    component p = UintTag(isActive, 16);
    p.in <== in;

    out <== p.out;
}

template Uint16TagArray(isActive,N) {
    signal input in[N];
    signal output {uint16} out[N];

    component p = UintTagArray(isActive, N, 16);
    p.in <== in;

    out <== p.out;
}

template Uint24Tag(isActive) {
    signal input in;
    signal output {uint24} out;

    component p = UintTag(isActive, 24);
    p.in <== in;

    out <== p.out;
}

template Uint24TagArray(isActive,N) {
    signal input in[N];
    signal output {uint24} out[N];

    component p = UintTagArray(isActive, N, 24);
    p.in <== in;

    out <== p.out;
}


template Uint32Tag(isActive) {
    signal input in;
    signal output {uint32} out;

    component p = UintTag(isActive, 32);
    p.in <== in;

    out <== p.out;
}

template Uint32TagArray(isActive,N) {
    signal input in[N];
    signal output {uint32} out[N];

    component p = UintTagArray(isActive, N, 32);
    p.in <== in;

    out <== p.out;
}

template Uint40Tag(isActive) {
    signal input in;
    signal output {uint40} out;

    component p = UintTag(isActive, 40);
    p.in <== in;

    out <== p.out;
}

template Uint64Tag(isActive) {
    signal input in;
    signal output {uint64} out;

    component p = UintTag(isActive, 64);
    p.in <== in;

    out <== p.out;
}

template Uint70Tag(isActive) {
    signal input in;
    signal output {uint70} out;

    component p = UintTag(isActive, 70);
    p.in <== in;

    out <== p.out;
}

template Uint96Tag(isActive) {
    signal input in;
    signal output {uint96} out;

    component p = UintTag(isActive, 96);
    p.in <== in;

    out <== p.out;
}

template Uint128Tag(isActive) {
    signal input in;
    signal output {uint128} out;

    component p = UintTag(isActive, 128);
    p.in <== in;

    out <== p.out;
}

template Uint160Tag(isActive) {
    signal input in;
    signal output {uint160} out;

    component p = UintTag(isActive, 160);
    p.in <== in;

    out <== p.out;
}

template Uint168Tag(isActive) {
    signal input in;
    signal output {uint168} out;

    component p = UintTag(isActive, 168);
    p.in <== in;

    out <== p.out;
}

template UintTagArray(isActive,N, nBits) {
    signal input in[N];
    signal output {uint} out[N];

    component p[N];
    for(var i = 0; i < N; i++) {
        p[i] = UintTag(isActive,nBits);
        p[i].in <== in[i];
        out[i] <== p[i].out;
    }
}

template Uint64TagArray(isActive,N) {
    signal input in[N];
    signal output {uint64} out[N];

    component p = UintTagArray(isActive,N,64);
    p.in <== in;
    out <== p.out;
}

template Uint168TagArray(isActive,N) {
    signal input in[N];
    signal output {uint168} out[N];

    component p = UintTagArray(isActive,N,168);
    p.in <== in;
    out <== p.out;
}

template Uint196Tag(isActive) {
    signal input in;
    signal output {uint196} out;

    component p = UintTag(isActive, 196);
    p.in <== in;

    out <== p.out;
}

template Uint240Tag(isActive) {
    signal input in;
    signal output {uint240} out;

    component p = UintTag(isActive, 240);
    p.in <== in;

    out <== p.out;
}

template Uint240TagArray(isActive,N) {
    signal input in[N];
    signal output {uint240} out[N];

    component p = UintTagArray(isActive, N, 240);
    p.in <== in;

    out <== p.out;
}


template Uint252Tag(isActive) {
    signal input in;
    signal output {uint252} out;

    component p = UintTag(isActive, 252);
    p.in <== in;

    out <== p.out;
}

template Uint252TagArray(isActive,N) {
    signal input in[N];
    signal output {uint252} out[N];

    component p = UintTagArray(isActive, N, 252);
    p.in <== in;

    out <== p.out;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Non Zero UINTs //////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template NonZeroUintTag(isActive, nBits) {
    signal input in;
    signal output {non_zero_uint} out;

    assert(nBits < 252);

    component n2b;
    if ( isActive ) {
        n2b = GreaterThan(nBits);
        n2b.in[0] <== 0;
        n2b.in[1] <== in;
        n2b.out === 1;
    }
    out <== in;
}

template NonZeroUintTagArray(isActive,N, nBits) {
    signal input in[N];
    signal output {non_zero_uint} out[N];

    component p[N];
    for(var i = 0; i < N; i++) {
        p[i] = NonZeroUintTag(isActive,nBits);
        p[i].in <== in[i];
        out[i] <== p[i].out;
    }
}

template NonZeroUint2Tag(isActive) {
    signal input in;
    signal output {non_zero_uint2} out;

    component p = NonZeroUintTag(isActive, 2);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint3Tag(isActive) {
    signal input in;
    signal output {non_zero_uint3} out;

    component p = NonZeroUintTag(isActive, 3);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint4Tag(isActive) {
    signal input in;
    signal output {non_zero_uint4} out;

    component p = NonZeroUintTag(isActive, 4);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint5Tag(isActive) {
    signal input in;
    signal output {non_zero_uint5} out;

    component p = NonZeroUintTag(isActive, 5);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint6Tag(isActive) {
    signal input in;
    signal output {non_zero_uint6} out;

    component p = NonZeroUintTag(isActive, 6);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint8Tag(isActive) {
    signal input in;
    signal output {non_zero_uint8} out;

    component p = NonZeroUintTag(isActive, 8);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint16Tag(isActive) {
    signal input in;
    signal output {non_zero_uint16} out;

    component p = NonZeroUintTag(isActive, 16);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint24Tag(isActive) {
    signal input in;
    signal output {non_zero_uint24} out;

    component p = NonZeroUintTag(isActive, 24);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint32Tag(isActive) {
    signal input in;
    signal output {non_zero_uint32} out;

    component p = NonZeroUintTag(isActive, 32);
    p.in <== in;
    out <== p.out;
}

template NonZeroUint32TagArray(isActive,N) {
    signal input in[N];
    signal output {non_zero_uint32} out[N];

    out <== NonZeroUintTagArray(isActive,N,32)(in);
}

template NonZeroUint40Tag(isActive) {
    signal input in;
    signal output {non_zero_uint40} out;

    component p = NonZeroUintTag(isActive, 40);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint64Tag(isActive) {
    signal input in;
    signal output {non_zero_uint64} out;

    component p = NonZeroUintTag(isActive, 64);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint64TagArray(isActive,N) {
    signal input in[N];
    signal output {non_zero_uint64} out[N];

    component p = NonZeroUintTagArray(isActive, N, 64);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint70Tag(isActive) {
    signal input in;
    signal output {non_zero_uint70} out;

    component p = NonZeroUintTag(isActive, 70);
    p.in <== in;

    out <== p.out;
}

template NonZeroUint96Tag(isActive) {
    signal input in;
    signal output {non_zero_uint96} out;

    component p = NonZeroUintTag(isActive, 96);
    p.in <== in;

    out <== p.out;
}
template NonZeroUint128Tag(isActive) {
    signal input in;
    signal output {non_zero_uint128} out;

    component p = NonZeroUintTag(isActive, 128);
    p.in <== in;

    out <== p.out;
}
template NonZeroUint196Tag(isActive) {
    signal input in;
    signal output {non_zero_uint196} out;

    component p = NonZeroUintTag(isActive, 196);
    p.in <== in;

    out <== p.out;
}

function Active() {
    return 1;
}

function NonActive() {
    return 0;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// FFs /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template FieldTag() {
    signal input in;
    signal output {ff} out;

    out <== in;
}

template FieldTagArray(N) {
    signal input in[N];
    signal output {sub_order_ff} out[N];

    out <== in;
}

template FieldTag2DimArray(N,M) {
    signal input in[N][M];
    signal output {sub_order_ff} out[N][M];

    out <== in;
}
template BabyJubJubSubOrderTag(isActive) {
    signal input in;
    signal output {sub_order_bj_sf} out;
    component n2b;
    if ( isActive ) {
        n2b = Num2Bits(252);
        n2b.in <== in;
    }
    out <== in;
}

template BabyJubJubSubOrderTagArray(isActive,N) {
    signal input in[N];
    signal output {sub_order_bj_sf} out[N];
    component p[N];
    for(var i = 0; i < N; i++) {
        p[i] = BabyJubJubSubOrderTag(isActive);
        p[i].in <== in[i];
    }
    out <== in;
}

template BabyJubJubSubOrderTag2DimArray(isActive,N,M) {
    signal input in[N][M];
    signal output {sub_order_bj_sf} out[N][M];

    component p[N][M];
    for(var i = 0; i < N; i++) {
        for(var j = 0; j < M; j++) {
            p[i][j] = BabyJubJubSubOrderTag(isActive);
            p[i][j].in <== in[i];
        }
    }

    out <== in;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MATH ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//template SafeAdderUint(nBits) {
//
//}
