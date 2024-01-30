//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "./multiOR.circom";

include "../../../node_modules/circomlib/circuits/babyjub.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";
include "../../../node_modules/circomlib/circuits/escalarmulany.circom";

// ------------- scalars-size --------------------------------
// 1) 1 x 64 (zAsset)
// 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
// 3) nUtxoIn x 64 amount
// 4) nUtxoOut x 64 amount
// 5) MAX(nUtxoIn,nUtxoOut) x ( utxo-in-origin-zones-ids & utxo-out-target-zone-ids - 32 bit )
// ------------------------------------------------------------
template DataEscrowSerializerTest(nUtxoIn,nUtxoOut) {
    signal input zAsset;                         // 64 bit
    signal input zAccountId;                     // 24 bit
    signal input zAccountZoneId;                 // 16 bit

    signal input utxoInAmount[nUtxoIn];          // 64 bit
    signal input utxoOutAmount[nUtxoOut];        // 64 bit

    signal input utxoInOriginZoneId[nUtxoIn];    // 16 bit
    signal input utxoOutTargetZoneId[nUtxoOut];  // 16 bit

    // signal input utxoInTargetZoneId[nUtxoIn];    // 16 bit
    // signal input utxoOutOriginZoneId[nUtxoOut];  // 16 bit

    // each signal will be < 2^64
    signal output out[1+1+nUtxoIn+nUtxoOut+nUtxoIn+nUtxoOut];

    // ---------------- Scalars ----------------------
    // 1) 1 x 64 (zAsset) ----------------------------
    assert(zAsset < 2**32);
    out[0] <== zAsset;

    // 2) 1 x 64 (zAccountId << 16 | zAccountZoneId) --
    assert(zAccountId < 2**24);
    assert(zAccountZoneId < 2**16);

    signal zAccountId_zAccountZoneId;
    zAccountId_zAccountZoneId <-- zAccountId << 16 | zAccountZoneId;

    out[1] <== zAccountId_zAccountZoneId;

    // 3) nUtxoIn x 64 amount
    for (var j = 0; j < nUtxoIn; j++) {
        assert(utxoInAmount[j] < 2**64);
        out[1+1+j] <== utxoInAmount[j];
    }
    // 4) nUtxoOut x 64 amount ------------------
    for (var j = 0; j < nUtxoOut; j++) {
        assert(utxoOutAmount[j] < 2**64);
        out[1+1+nUtxoIn+j] <== utxoOutAmount[j];
    }

    signal utxoInOriginZoneIdShifted[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        utxoInOriginZoneIdShifted[j] <-- utxoInOriginZoneId[j] << 16;
    }
    var max_nUtxoIn_nUtxoOut = nUtxoIn > nUtxoOut ? nUtxoIn:nUtxoOut;
    signal utxoInOriginZoneIdUtxoOutTargetZoneIdOR[max_nUtxoIn_nUtxoOut];

    for (var j = 0; j < max_nUtxoIn_nUtxoOut; j++) {
        if( j < nUtxoIn && j < nUtxoOut ) {
            utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j] <-- utxoInOriginZoneIdShifted[j] | utxoOutTargetZoneId[j];
        } else {
            if( j < nUtxoIn ) { // j > nUtxoOut ---> utxo-out-targetZoneId - set to be zero - assimetric case
                utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j] <-- utxoInOriginZoneIdShifted[j] | 0;
            } else {            // j > nUtxoIn  ---> utxo-in-originZoneId -  set to be zero - assimetric case
                utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j] <-- 0 | utxoOutTargetZoneId[j];
            }
        }
        out[1+1+nUtxoIn+nUtxoOut+j] <== utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j];
    }
}

template DaoDataEscrowSerializerTest(nUtxoIn,nUtxoOut) {
    signal input zAccountId;                     // 24 bit
    signal input zAccountZoneId;                 // 16 bit

    signal input utxoInOriginZoneId[nUtxoIn];    // 16 bit
    signal input utxoOutTargetZoneId[nUtxoOut];  // 16 bit

    // each signal will be < 2^64
    signal output out[1+nUtxoIn+nUtxoOut];

    // ---------------- Scalars ----------------
    // 1) 1 x 64 (zAccount | zAccountZoneID) ---
    assert(zAccountId < 2**24);
    assert(zAccountZoneId < 2**16);
    component multiOR_zAccountId_zAccountZoneId = MultiOR(2);
    signal tmp;
    tmp <-- zAccountId << 16;
    multiOR_zAccountId_zAccountZoneId.in[0] <== tmp;
    multiOR_zAccountId_zAccountZoneId.in[1] <== zAccountZoneId;
    out[0] <== multiOR_zAccountId_zAccountZoneId.out;

    signal utxoInOriginZoneIdShifted[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        utxoInOriginZoneIdShifted[j] <-- utxoInOriginZoneId[j] << 16;
    }
    var max_nUtxoIn_nUtxoOut = nUtxoIn > nUtxoOut ? nUtxoIn:nUtxoOut;
    signal utxoInOriginZoneIdUtxoOutTargetZoneIdOR[max_nUtxoIn_nUtxoOut];

    for (var j = 0; j < max_nUtxoIn_nUtxoOut; j++) {
        if( j < nUtxoIn && j < nUtxoOut ) {
            utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j] <-- utxoInOriginZoneIdShifted[j] | utxoOutTargetZoneId[j];
        } else {
            if( j < nUtxoIn ) { // j > nUtxoOut ---> targetZoneId - set to be zero - assimetric case
                utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j] <-- utxoInOriginZoneIdShifted[j] | 0;
            } else {            // j > nUtxoIn ---> originZoneId - set to be zero - assimetric case
                utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j] <-- 0 | utxoOutTargetZoneId[j];
            }
        }
        out[1+j] <== utxoInOriginZoneIdUtxoOutTargetZoneIdOR[j];
    }
  ../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../..///
    // OLD SCHEM../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../
  ../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../..///
    // 2) nUtxoIn x ( zones-ids - 32 bit ) ------
    /*
    signal utxoInOriginZoneIdShifted[nUtxoIn];
    signal utxoInOriginZoneIdOr[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        utxoInOriginZoneIdShifted[j] <-- utxoInOriginZoneId[j] << 16;
        utxoInOriginZoneIdOr[j] <-- utxoInOriginZoneIdShifted[j] | utxoInTargetZoneId[j];

        out[1+j] <== utxoInOriginZoneIdOr[j];
    }
    */

    // 3) nUtxoOut x ( zones-ids - 32 bit ) -----
    /*
    signal utxoOutOriginZoneIdShifted[nUtxoOut];
    signal utxoOutOriginZoneIdOr[nUtxoOut];
    for (var j = 0; j < nUtxoOut; j++) {
        utxoOutOriginZoneIdShifted[j] <-- utxoOutOriginZoneId[j] << 16;
        utxoOutOriginZoneIdOr[j] <-- utxoOutOriginZoneIdShifted[j] | utxoOutTargetZoneId[j];

        out[1+nUtxoIn+j] <== utxoOutOriginZoneIdOr[j];
    }
    */
}
