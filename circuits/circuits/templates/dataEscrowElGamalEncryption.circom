//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

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
// 1) 3 x 64 (zAsset)
// 2) 1 x 64 (zAccount)
// 3) nUtxoIn x 64 amount
// 4) nUtxoOut x 64 amount
// 5) nUtxoIn x ( zones-ids - origin & target - 32 bit )
// 6) nUtxoOut x ( zones-ids - origin & target - 32 bit )
// ------------------------------------------------------------
template DataEscrowSerializer(nUtxoIn,nUtxoOut) {
    signal input zAsset;                         // 160 bit
    signal input zAccountId;                     // 24 bit

    signal input utxoInAmount[nUtxoIn];          // 64 bit
    signal input utxoOutAmount[nUtxoOut];        // 64 bit

    signal input utxoInOriginZoneId[nUtxoIn];    // 16 bit
    signal input utxoInTargetZoneId[nUtxoIn];    // 16 bit

    signal input utxoOutOriginZoneId[nUtxoOut];  // 16 bit
    signal input utxoOutTargetZoneId[nUtxoOut];  // 16 bit

    // each signal will be < 2^64
    signal output out[3+1+nUtxoIn+nUtxoOut+nUtxoIn+nUtxoOut];

    // ---------------- Scalars ----------------
    // 1) 3 x 64 (zAsset) ----------------------
    component n2b_zAsset = Num2Bits(160);
    n2b_zAsset.in <== zAsset;
    component b2n_0 = Bits2Num(32);
    for (var j = 0; j < 32; j++) {
        b2n_0.in[j] <== n2b_zAsset.out[160-1-j];
    }
    component b2n_1 = Bits2Num(64);
    for (var j = 0; j < 64; j++) {
        b2n_1.in[j] <== n2b_zAsset.out[160-1-32-j];
    }
    component b2n_2 = Bits2Num(64);
    for (var j = 0; j < 64; j++) {
        b2n_2.in[j] <== n2b_zAsset.out[160-1-32-64-j];
    }
    out[0] <== b2n_0.out;
    out[1] <== b2n_1.out;
    out[2] <== b2n_2.out;
    // 2) 1 x 64 (zAccount) ---------------------
    out[3] <== zAccountId;
    // 3) nUtxoIn x 64 amount
    for (var j = 0; j < nUtxoIn; j++) {
        out[3+1+j] <== utxoInAmount[j];
    }
    // 4) nUtxoOut x 64 amount ------------------
    for (var j = 0; j < nUtxoOut; j++) {
        out[3+1+nUtxoIn+j] <== utxoOutAmount[j];
    }
    // 5) nUtxoIn x ( zones-ids - 32 bit ) ------
    signal utxoInOriginZoneIdShifted[nUtxoIn];
    signal utxoInOriginZoneIdOr[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        utxoInOriginZoneIdShifted[j] <-- utxoInOriginZoneId[j] << 16;
        utxoInOriginZoneIdOr[j] <-- utxoInOriginZoneIdShifted[j] | utxoInTargetZoneId[j];

        out[3+1+nUtxoIn+nUtxoOut+j] <== utxoInOriginZoneIdOr[j];
    }
    // 6) nUtxoOut x ( zones-ids - 32 bit ) -----
    signal utxoOutOriginZoneIdShifted[nUtxoOut];
    signal utxoOutOriginZoneIdOr[nUtxoOut];
    for (var j = 0; j < nUtxoOut; j++) {
        utxoOutOriginZoneIdShifted[j] <-- utxoOutOriginZoneId[j] << 16;
        utxoOutOriginZoneIdOr[j] <-- utxoOutOriginZoneIdShifted[j] | utxoOutTargetZoneId[j];

        out[3+1+nUtxoIn+nUtxoOut+nUtxoIn+j] <== utxoOutOriginZoneIdOr[j];
    }
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

    signal input utxoInOriginZoneId[nUtxoIn];    // 16 bit
    signal input utxoInTargetZoneId[nUtxoIn];    // 16 bit

    signal input utxoOutOriginZoneId[nUtxoOut];  // 16 bit
    signal input utxoOutTargetZoneId[nUtxoOut];  // 16 bit

    // each signal will be < 2^64
    signal output out[1+nUtxoIn+nUtxoOut];

    // ---------------- Scalars ----------------
    // 1) 1 x 64 (zAccount) ---------------------
    out[0] <== zAccountId;
    // 2) nUtxoIn x ( zones-ids - 32 bit ) ------
    signal utxoInOriginZoneIdShifted[nUtxoIn];
    signal utxoInOriginZoneIdOr[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        utxoInOriginZoneIdShifted[j] <-- utxoInOriginZoneId[j] << 16;
        utxoInOriginZoneIdOr[j] <-- utxoInOriginZoneIdShifted[j] | utxoInTargetZoneId[j];

        out[1+j] <== utxoInOriginZoneIdOr[j];
    }
    // 3) nUtxoOut x ( zones-ids - 32 bit ) -----
    signal utxoOutOriginZoneIdShifted[nUtxoOut];
    signal utxoOutOriginZoneIdOr[nUtxoOut];
    for (var j = 0; j < nUtxoOut; j++) {
        utxoOutOriginZoneIdShifted[j] <-- utxoOutOriginZoneId[j] << 16;
        utxoOutOriginZoneIdOr[j] <-- utxoOutOriginZoneIdShifted[j] | utxoOutTargetZoneId[j];

        out[1+nUtxoIn+j] <== utxoOutOriginZoneIdOr[j];
    }
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
