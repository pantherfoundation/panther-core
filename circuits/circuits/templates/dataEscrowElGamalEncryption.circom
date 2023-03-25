//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./multiOR.circom";

include "../../node_modules/circomlib/circuits/babyjub.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/escalarmulany.circom";

template DataEscrowElGamalEncryption(ScalarsSize, PointsSize) {
    signal input ephimeralRandom;                               // randomness
    signal input scalarMessage[ScalarsSize];                    // scalars up to 64 bit data to encrypt
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key
    signal output ephimeralPubKey[2];                           // ephimeral public-key
    signal output encryptedMessage[ScalarsSize+PointsSize][2];  // encrypted data

    assert(ScalarsSize > 0);
    assert(PointsSize > 0);

    // [0] - Create ephimeral public key
    component drv_rG = BabyPbk();
    drv_rG.in <== ephimeralRandom;
    ephimeralPubKey[0] <== drv_rG.Ax;
    ephimeralPubKey[1] <== drv_rG.Ay;

    // [1] - ephimeralRandom * pubKey + M, where M = m * G
    component drv_mG[ScalarsSize];

    // ephimeralRandom * pubKey
    component n2b = Num2Bits(253);

    n2b.in <== ephimeralRandom;

    component drv_ephimeralRandomPublicKey = EscalarMulAny(253);

    drv_ephimeralRandomPublicKey.p[0] <== pubKey[0];
    drv_ephimeralRandomPublicKey.p[1] <== pubKey[1];

    for (var i = 0; i < 253; i++) {
        drv_ephimeralRandomPublicKey.e[i] <== n2b.out[i];
    }

    component drv_mGrY[ScalarsSize + PointsSize];

    for (var j = 0; j < ScalarsSize; j++) {
        // M = m * G
        drv_mG[j] = BabyPbk();
        drv_mG[j].in <== scalarMessage[j];
        // require `m < 2^64` - otherwise brute-force will be near to imposible
        assert(scalarMessage[j] < 2**64);

        // ephemeralRandom * pubKey + M
        drv_mGrY[j] = BabyAdd();
        drv_mGrY[j].x1 <== drv_mG[j].Ax;
        drv_mGrY[j].y1 <== drv_mG[j].Ay;
        drv_mGrY[j].x2 <== drv_ephimeralRandomPublicKey.out[0];
        drv_mGrY[j].y2 <== drv_ephimeralRandomPublicKey.out[1];

        // ecrypted data
        encryptedMessage[j][0] <== drv_mGrY[j].xout;
        encryptedMessage[j][1] <== drv_mGrY[j].yout;
    }

    for (var j = 0; j < PointsSize; j++) {
        // ephimeralRandom * pubKey + M
        drv_mGrY[ScalarsSize+j] = BabyAdd();
        drv_mGrY[ScalarsSize+j].x1 <== pointMessage[j][0];
        drv_mGrY[ScalarsSize+j].y1 <== pointMessage[j][1];
        drv_mGrY[ScalarsSize+j].x2 <== drv_ephimeralRandomPublicKey.out[0];
        drv_mGrY[ScalarsSize+j].y2 <== drv_ephimeralRandomPublicKey.out[1];

        // ecrypted data
        encryptedMessage[ScalarsSize+j][0] <== drv_mGrY[j].xout;
        encryptedMessage[ScalarsSize+j][1] <== drv_mGrY[j].yout;
    }
}

// ------------- scalars-size --------------------------------
// 1) 1 x 64 (zAsset)
// 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
// 3) nUtxoIn x 64 amount
// 4) nUtxoOut x 64 amount
// 5) MAX(nUtxoIn,nUtxoOut) x ( utxo-in-origin-zones-ids & utxo-out-target-zone-ids - 32 bit )
// ------------------------------------------------------------
template DataEscrowSerializer(nUtxoIn,nUtxoOut) {
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
    /*
    // 5) nUtxoIn x ( zones-ids - 32 bit ) ------
    signal utxoInOriginZoneIdShifted[nUtxoIn];
    signal utxoInOriginZoneIdOr[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        utxoInOriginZoneIdShifted[j] <-- utxoInOriginZoneId[j] << 16;
        utxoInOriginZoneIdOr[j] <-- utxoInOriginZoneIdShifted[j] | utxoInTargetZoneId[j];

        out[1+nUtxoIn+nUtxoOut+j] <== utxoInOriginZoneIdOr[j];
    }
    // 6) nUtxoOut x ( zones-ids - 32 bit ) -----
    signal utxoOutOriginZoneIdShifted[nUtxoOut];
    signal utxoOutOriginZoneIdOr[nUtxoOut];
    for (var j = 0; j < nUtxoOut; j++) {
        utxoOutOriginZoneIdShifted[j] <-- utxoOutOriginZoneId[j] << 16;
        utxoOutOriginZoneIdOr[j] <-- utxoOutOriginZoneIdShifted[j] | utxoOutTargetZoneId[j];

        out[1+nUtxoIn+nUtxoOut+nUtxoIn+j] <== utxoOutOriginZoneIdOr[j];
    }
    */
}

template DataEscrowElGamalEncryptionScalar(ScalarsSize) {
    signal input ephimeralRandom;                               // randomness
    signal input scalarMessage[ScalarsSize];                    // scalars up to 64 bit data to encrypt
    signal input pubKey[2];                                     // public key
    signal output ephimeralPubKey[2];                           // ephimeral public-key
    signal output encryptedMessage[ScalarsSize][2];             // encrypted data

    assert(ScalarsSize > 0);

    // [0] - Create ephimeral public key
    component drv_rG = BabyPbk();
    drv_rG.in <== ephimeralRandom;
    ephimeralPubKey[0] <== drv_rG.Ax;
    ephimeralPubKey[1] <== drv_rG.Ay;

    // [1] - ephimeralRandom * pubKey + M, where M = m * G
    component drv_mG[ScalarsSize];

    // ephimeralRandom * pubKey
    component n2b = Num2Bits(253);

    n2b.in <== ephimeralRandom;

    component drv_ephimeralRandomPublicKey = EscalarMulAny(253);

    drv_ephimeralRandomPublicKey.p[0] <== pubKey[0];
    drv_ephimeralRandomPublicKey.p[1] <== pubKey[1];

    for (var i = 0; i < 253; i++) {
        drv_ephimeralRandomPublicKey.e[i] <== n2b.out[i];
    }

    component drv_mGrY[ScalarsSize];

    for (var j = 0; j < ScalarsSize; j++) {
        // M = m * G
        drv_mG[j] = BabyPbk();
        drv_mG[j].in <== scalarMessage[j];
        // require `m < 2^64` - otherwise brute-force will be near to imposible
        assert(scalarMessage[j] < 2**64);

        // ephemeralRandom * pubKey + M
        drv_mGrY[j] = BabyAdd();
        drv_mGrY[j].x1 <== drv_mG[j].Ax;
        drv_mGrY[j].y1 <== drv_mG[j].Ay;
        drv_mGrY[j].x2 <== drv_ephimeralRandomPublicKey.out[0];
        drv_mGrY[j].y2 <== drv_ephimeralRandomPublicKey.out[1];

        // ecrypted data
        encryptedMessage[j][0] <== drv_mGrY[j].xout;
        encryptedMessage[j][1] <== drv_mGrY[j].yout;
    }
}

template DaoDataEscrowSerializer(nUtxoIn,nUtxoOut) {
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
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // OLD SCHEME ////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////
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

template DataEscrowElGamalEncryptionPoint(PointsSize) {
    signal input ephimeralRandom;                               // randomness
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key
    signal output ephimeralPubKey[2];                           // ephimeral public-key
    signal output encryptedMessage[PointsSize][2];              // encrypted data

    assert(PointsSize > 0);

    // [0] - Create ephimeral public key
    component drv_rG = BabyPbk();
    drv_rG.in <== ephimeralRandom;
    ephimeralPubKey[0] <== drv_rG.Ax;
    ephimeralPubKey[1] <== drv_rG.Ay;

    // [1] - ephimeralRandom * pubKey + M, where M is EC-point

    // ephimeralRandom * pubKey
    component n2b = Num2Bits(253);

    n2b.in <== ephimeralRandom;

    component drv_ephimeralRandomPublicKey = EscalarMulAny(253);

    drv_ephimeralRandomPublicKey.p[0] <== pubKey[0];
    drv_ephimeralRandomPublicKey.p[1] <== pubKey[1];

    for (var i = 0; i < 253; i++) {
        drv_ephimeralRandomPublicKey.e[i] <== n2b.out[i];
    }

    component drv_mGrY[PointsSize];

    for (var j = 0; j < PointsSize; j++) {
        // ephimeralRandom * pubKey + M
        drv_mGrY[j] = BabyAdd();
        drv_mGrY[j].x1 <== pointMessage[j][0];
        drv_mGrY[j].y1 <== pointMessage[j][1];
        drv_mGrY[j].x2 <== drv_ephimeralRandomPublicKey.out[0];
        drv_mGrY[j].y2 <== drv_ephimeralRandomPublicKey.out[1];

        // ecrypted data
        encryptedMessage[j][0] <== drv_mGrY[j].xout;
        encryptedMessage[j][1] <== drv_mGrY[j].yout;
    }
}
