//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/babyjub.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/escalarmulany.circom";

// ZKP Token
function ZkpToken() {
    return 0;
}

function ZkpTokenId() {
    return 0;
}

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

// the only 1 points in the zZone data-escrow is the ephemeral pub-key of the main data-escrow safe
function ZZoneDataEscrowPoints_Fn() {
    return 1;
}

function ZZoneDataEscrowEncryptedPoints_Fn() {
    return ZZoneDataEscrowPoints_Fn();
}
// ------------- pudding-points-size -------------
function DataEscrowPaddingPointSize_Fn() {
    return 0;
}
// ------------- scalars-size --------------------------------
// 1) 1 x 64 (zAsset)
// 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
// 3) 1 x 32 (zAccountNonce)
// 4) nUtxoIn x 64 amount
// 5) nUtxoOut x 64 amount
// 6) MAX(nUtxoIn,nUtxoOut) x ( , utxoInPathIndices[..] << 32 bit | utxo-in-origin-zones-ids << 16 | utxo-out-target-zone-ids << 0 )
function DataEscrowScalarSize_Fn( nUtxoIn, nUtxoOut ) {
    var dataEscrowScalarSize =  1 + 1 + 1 + nUtxoIn + nUtxoOut + MaxUtxoInOut_Fn(nUtxoIn,nUtxoOut);
    return dataEscrowScalarSize;
}
// ------------- ec-points-size -------------
// 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)
function DataEscrowPointSize_Fn( nUtxoOut ) {
    return nUtxoOut;
}

function DataEscrowEncryptedPoints_Fn( nUtxoIn, nUtxoOut ) {
    return DataEscrowPaddingPointSize_Fn() + DataEscrowScalarSize_Fn( nUtxoIn, nUtxoOut ) + DataEscrowPointSize_Fn( nUtxoOut );
}

// the only 1 point in the Dao data-escrow is the ephemeral pub-key of the main data-escrow safe
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

template IsNotZero(){
    signal input in;
    signal output out;
    component isZero = IsZero();
    isZero.in <== in;
    out <== 1 - isZero.out;
}

// Checks if the first input signal is lesser than or equal to the second input signal when input signal enabled is true.
template LessEqThanWhenEnabled(n){
    signal input enabled;
    signal input in[2];

    // 0 - when 2 <= 3, 1 - when 1 <= 1 or 2
    component lt = LessEqThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    // 1 - when `enabled > 0`, 0 - when `enabled == 0`
    component isNotZero = IsNotZero();
    isNotZero.in <== enabled;

    // when `enabled != 0` it will require `in[0] <= in[1]`
    // when `enabled == 0` it will nullify equation from both sides
    lt.out * isNotZero.out === 1 * isNotZero.out;
}

// Checks if the first input signal is lesser than or equal to the second input signal when input signal enabled is true.
template LessThanWhenEnabled(n){
    signal input enabled;
    signal input in[2];

    // 0 - when 2 <= 3, 1 - when 1 <= 1 or 2
    component lt = LessThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    // 1 - when `enabled > 0`, 0 - when `enabled == 0`
    component isNotZero = IsNotZero();
    isNotZero.in <== enabled;

    // when `enabled != 0` it will require `in[0] <= in[1]`
    // when `enabled == 0` it will nullify equation from both sides
    lt.out * isNotZero.out === 1 * isNotZero.out;
}

template RangeCheck(n) {
    signal input lowerBound;
    signal input upperBound;
    signal input enabled;
    signal input in;

    component l1 = LessEqThanWhenEnabled(n);
    component l2 = LessEqThanWhenEnabled(n);

    l1.in[0] <== lowerBound;
    l1.in[1] <== in;
    l1.enabled <== enabled;

    l2.in[0] <== in;
    l2.in[1] <== upperBound;
    l2.enabled <== enabled;
}

template ForceLessEqThan(n){
    signal input in[2];

    component lt = LessEqThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    // always require `in[0] <= in[1]`
    lt.out === 1;
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

template Uint48Tag(isActive) {
    signal input in;
    signal output {uint48} out;

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

template Uint48TagArray(isActive,N) {
    signal input in[N];
    signal output {uint48} out[N];

    component p = UintTagArray(isActive,N,48);
    p.in <== in;
    out <== p.out;
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
template SnarkFieldTag() {
    signal input in;
    signal output {snark_ff} out;

    out <== in;
}

template SnarkFieldTagArray(N) {
    signal input in[N];
    signal output {snark_ff} out[N];

    out <== in;
}

template SnarkFieldTag2DimArray(N,M) {
    signal input in[N][M];
    signal output {snark_ff} out[N][M];

    out <== in;
}

template BabyJubJubPointTag(isActive) {
    signal input in[2];
    signal output {bj_point} out;
    component p;
    if( isActive ) {
        p = BabyCheck();
        p.x <== in[0];
        p.y <== in[1];
    }
    out <== in;
}

template BabyJubJubSubGroupPointTag(isActive) {
    signal input in[2];
    signal output {sub_order_bj_p} out[2];

    var suborder = 2736030358979909402780800718157159386076813972158567259200215660948447373041;

    component babyCheck;
    component pvkBits;
    component eMul;
    if( isActive ) {
        // Ensure the point [x,y] is in the Baby Jubjub curve
        babyCheck = BabyCheck();
        babyCheck.x <== in[0];
        babyCheck.y <== in[1];

        // Scalar multiplication of a point from the subgroup by the
        // subgroup's order results in the identity point ([0,1]).
        pvkBits = Num2Bits(253);
        pvkBits.in <== suborder;

        eMul = EscalarMulAny(253);
        for (var i=0; i<253; i++) {
            eMul.e[i] <== pvkBits.out[i];
        }
        eMul.p[0] <== in[0];
        eMul.p[1] <== in[1];

        eMul.out[0] === 0;
        eMul.out[1] === 1;

    }
    out <== in;
}

template BabyJubJubSubGroupPointTagArray(isActive,N) {
    signal input in[N][2];
    signal output {sub_order_bj_p} out[N][2];

    component p[N];
    for(var i = 0; i < N; i++) {
        p[i] = BabyJubJubSubGroupPointTag(isActive);
        p[i].in[0] <== in[i][0];
        p[i].in[1] <== in[i][1];
    }
    out <== in;
}

template BabyJubJubSubOrderTag(isActive) {
    signal input in;
    signal output {sub_order_bj_sf} out;
    var suborder = 2736030358979909402780800718157159386076813972158567259200215660948447373041;
    component n2b;
    if ( isActive ) {
        n2b = LessThan(251);
        n2b.in[0] <== in;
        n2b.in[1] <== suborder;
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
template ExtractLSBits(M, N) { // extract M out of N LSB bits
    signal input in;
    signal output out;
    assert(0 <= N <= 254);
    assert(0 <= M <= N);
    component n = Num2Bits(N);
    n.in <== in;
    component b = Bits2Num(M);
    for(var i = 0; i < M; i++) {
        b.in[i] <== n.out[i];
    }
    out <== b.out;
}

template ExtractToken() {
    signal input {uint168}  in;
    signal output {uint160} out;

    out <== ExtractLSBits(160,168)(in);
}

