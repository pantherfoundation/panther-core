//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/babyjub.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/escalarmulany.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

template DataEscrowElGamalEncryption(ScalarsSize, PointsSize) {
    signal input ephemeralRandom;                               // randomness
    signal input scalarMessage[ScalarsSize];                    // scalars up to 64 bit data to encrypt
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key (assumed to be priv-key * B8)
    signal output ephemeralPubKey[2];                           // ephemeral public-key
    signal output encryptedMessage[ScalarsSize+PointsSize][2];  // encrypted data

    assert(ScalarsSize > 0);
    assert(PointsSize > 0);

    var ScalarsAndPointSize = ScalarsSize + PointsSize;

    // [0] - Create ephemeral public key
    component ephemeralPubKeyBuilder = EphemeralPubKeysBuilder(ScalarsAndPointSize);
    ephemeralPubKeyBuilder.pubKey[0] <== pubKey[0];
    ephemeralPubKeyBuilder.pubKey[1] <== pubKey[1];
    ephemeralPubKeyBuilder.ephemeralRandom <== ephemeralRandom;
    ephemeralPubKey[0] <== ephemeralPubKeyBuilder.ephemeralPubKey[0][0];
    ephemeralPubKey[1] <== ephemeralPubKeyBuilder.ephemeralPubKey[0][1];

    // [1] - ephemeralRandom * pubKey + M, where M = m * G
    component drv_mG[ScalarsSize];

    component drv_mGrY[ScalarsAndPointSize];

    for (var j = 0; j < ScalarsSize; j++) {
        // M = m * B8
        drv_mG[j] = BabyPbk();
        drv_mG[j].in <== scalarMessage[j];
        // require `m < 2^64` - otherwise brute-force will be near to impossible
        assert(scalarMessage[j] < 2**64);

        // ephemeralRandom * pubKey + M
        drv_mGrY[j] = BabyAdd();
        drv_mGrY[j].x1 <== drv_mG[j].Ax;
        drv_mGrY[j].y1 <== drv_mG[j].Ay;
        drv_mGrY[j].x2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[j][0];
        drv_mGrY[j].y2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[j][1];

        // encrypted data
        encryptedMessage[j][0] <== drv_mGrY[j].xout;
        encryptedMessage[j][1] <== drv_mGrY[j].yout;
    }

    for (var j = 0; j < PointsSize; j++) {
        // ephemeralRandom * pubKey + M
        drv_mGrY[ScalarsSize+j] = BabyAdd();
        drv_mGrY[ScalarsSize+j].x1 <== pointMessage[j][0];
        drv_mGrY[ScalarsSize+j].y1 <== pointMessage[j][1];
        drv_mGrY[ScalarsSize+j].x2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[ScalarsSize+j][0];
        drv_mGrY[ScalarsSize+j].y2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[ScalarsSize+j][1];

        // encrypted data
        encryptedMessage[ScalarsSize+j][0] <== drv_mGrY[ScalarsSize+j].xout;
        encryptedMessage[ScalarsSize+j][1] <== drv_mGrY[ScalarsSize+j].yout;
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

    // each signal will be < 2^64
    signal output out[1+1+nUtxoIn+nUtxoOut+nUtxoIn+nUtxoOut];

    // ---------------- Scalars ----------------------
    // 1) 1 x 64 (zAsset) ----------------------------
    assert(zAsset < 2**32);
    out[0] <== zAsset;

    // 2) 1 x 64 (zAccountId << 16 | zAccountZoneId) --
    assert(zAccountId < 2**24);
    assert(zAccountZoneId < 2**16);

    component n2b_zAccountId = Num2Bits(24);
    n2b_zAccountId.in <== zAccountId;

    component n2b_zAccountZoneId = Num2Bits(16);
    n2b_zAccountZoneId.in <== zAccountZoneId;

    component b2n_zAccountId_zAccountZoneId = Bits2Num(24+16);
    for(var i = 0; i < 16; i++) {
        b2n_zAccountId_zAccountZoneId.in[i] <== n2b_zAccountZoneId.out[i];
    }

    for(var i = 0; i < 24; i++) {
        b2n_zAccountId_zAccountZoneId.in[i+16] <== n2b_zAccountId.out[i];
    }

    out[1] <== b2n_zAccountId_zAccountZoneId.out;

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

    // 5) nUtxoIn x originZoneId + nUtxoOut x targetZoneId
    component n2b_utxoInOriginZoneId[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        n2b_utxoInOriginZoneId[j] = Num2Bits(16);
        n2b_utxoInOriginZoneId[j].in <== utxoInOriginZoneId[j];
    }

    component n2b_utxoOutTargetZoneId[nUtxoOut];
    for (var j = 0; j < nUtxoOut; j++) {
        n2b_utxoOutTargetZoneId[j] = Num2Bits(16);
        n2b_utxoOutTargetZoneId[j].in <== utxoOutTargetZoneId[j];
    }

    var max_nUtxoIn_nUtxoOut = nUtxoIn > nUtxoOut ? nUtxoIn:nUtxoOut;
    component b2n_utxoInOriginZoneId_utxoOutTargetZoneId[max_nUtxoIn_nUtxoOut];

    for (var j = 0; j < max_nUtxoIn_nUtxoOut; j++) {
        b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j] = Bits2Num(32);
        if( j < nUtxoIn && j < nUtxoOut ) {
            for(var i = 0; i < 16; i++) {
                b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[i] <== n2b_utxoOutTargetZoneId[j].out[i];
            }
            for(var i = 0; i < 16; i++) {
                b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[16+i] <== n2b_utxoInOriginZoneId[j].out[i];
            }
        } else {
            if( j < nUtxoIn ) { // j > nUtxoOut ---> utxo-out-targetZoneId - set to be zero - assimetric case
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[i] <== 0;
                }
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[16+i] <== n2b_utxoInOriginZoneId[j].out[i];
                }
            } else {            // j > nUtxoIn  ---> utxo-in-originZoneId -  set to be zero - assimetric case
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[i] <== n2b_utxoOutTargetZoneId[j].out[i];
                }
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[16+i] <== 0;
                }
            }
        }
        out[1+1+nUtxoIn+nUtxoOut+j] <== b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].out;
    }
}

template EphemeralPubKeysBuilder(nPubKeys) {
    signal input pubKey[2];                             // pub-key of trust-providers
    signal input ephemeralRandom;                       // random per transaction
    signal output ephemeralRandoms[nPubKeys];           // derived randoms: eRand[i] = Hash( ePubKey[i] = eRand[i-1] * G ), eRand[0] = ephemeralRandom
    signal output ephemeralPubKey[nPubKeys][2];         // derived ephemeral pub-keys: ePubKey[i] = eRand[i-1] * G
    signal output ephemeralRandomPubKey[nPubKeys][2];   // derived pub-keys: pubKey[i] = eRand[i] * pubKey

    assert(nPubKeys > 0);

    ephemeralRandoms[0] <== ephemeralRandom;

    component drv_rG[nPubKeys];
    drv_rG[0] = BabyPbk();
    drv_rG[0].in <== ephemeralRandoms[0];
    ephemeralPubKey[0][0] <== drv_rG[0].Ax;
    ephemeralPubKey[0][1] <== drv_rG[0].Ay;

    component hash[nPubKeys-1];

    for (var i = 1; i < nPubKeys; i++) {
        hash[i-1] = Poseidon(2);
        hash[i-1].inputs[0] <== drv_rG[i-1].Ax;
        hash[i-1].inputs[1] <== drv_rG[i-1].Ay;
        ephemeralRandoms[i] <== hash[i-1].out;

        drv_rG[i] = BabyPbk();
        drv_rG[i].in <== ephemeralRandoms[i-1];
        ephemeralPubKey[i][0] <== drv_rG[i].Ax;
        ephemeralPubKey[i][1] <== drv_rG[i].Ay;
    }

    // ephemeralRandom * pubKey
    component n2b[nPubKeys];
    component drv_ephemeralRandomPublicKey[nPubKeys];

    for (var i = 0; i < nPubKeys; i++) {
        n2b[i] = Num2Bits(253);
        n2b[i].in <== ephemeralRandoms[i];

        drv_ephemeralRandomPublicKey[i] = EscalarMulAny(253);
        drv_ephemeralRandomPublicKey[i].p[0] <== pubKey[0];
        drv_ephemeralRandomPublicKey[i].p[1] <== pubKey[1];

        for (var j = 0; j < 253; j++) {
            drv_ephemeralRandomPublicKey[i].e[j] <== n2b[i].out[j];
        }

        ephemeralRandomPubKey[i][0] <== drv_ephemeralRandomPublicKey[i].out[0];
        ephemeralRandomPubKey[i][1] <== drv_ephemeralRandomPublicKey[i].out[1];
    }

}

template DataEscrowElGamalEncryptionScalar(ScalarsSize) {
    signal input ephemeralRandom;                               // randomness
    signal input scalarMessage[ScalarsSize];                    // scalars up to 64 bit data to encrypt
    signal input pubKey[2];                                     // public key
    signal output ephemeralPubKey[2];                           // ephemeral public-key
    signal output encryptedMessage[ScalarsSize][2];             // encrypted data

    assert(ScalarsSize > 0);

    // [0] - Create ephemeral public key
    component ephemeralPubKeyBuilder = EphemeralPubKeysBuilder(ScalarsSize);
    ephemeralPubKeyBuilder.pubKey[0] <== pubKey[0];
    ephemeralPubKeyBuilder.pubKey[1] <== pubKey[1];
    ephemeralPubKeyBuilder.ephemeralRandom <== ephemeralRandom;

    ephemeralPubKey[0] <== ephemeralPubKeyBuilder.ephemeralPubKey[0][0];
    ephemeralPubKey[1] <== ephemeralPubKeyBuilder.ephemeralPubKey[0][1];

    // [1] - ephemeralRandom * pubKey + M, where M = m * G
    component drv_mG[ScalarsSize];
    component drv_mGrY[ScalarsSize];

    for (var j = 0; j < ScalarsSize; j++) {
        // M = m * G
        drv_mG[j] = BabyPbk();
        drv_mG[j].in <== scalarMessage[j];
        // require `m < 2^64` - otherwise brute-force will be near to impossible
        assert(scalarMessage[j] < 2**64);

        // ephemeralRandom * pubKey + M
        drv_mGrY[j] = BabyAdd();
        drv_mGrY[j].x1 <== drv_mG[j].Ax;
        drv_mGrY[j].y1 <== drv_mG[j].Ay;
        drv_mGrY[j].x2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[j][0];
        drv_mGrY[j].y2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[j][1];

        // encrypted data
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

    component n2b_zAccountId = Num2Bits(24);
    n2b_zAccountId.in <== zAccountId;

    component n2b_zAccountZoneId = Num2Bits(16);
    n2b_zAccountZoneId.in <== zAccountZoneId;

    component b2n_zAccountId_zAccountZoneId = Bits2Num(24+16);
    for(var i = 0; i < 16; i++) {
        b2n_zAccountId_zAccountZoneId.in[i] <== n2b_zAccountZoneId.out[i];
    }

    for(var i = 0; i < 24; i++) {
        b2n_zAccountId_zAccountZoneId.in[i+16] <== n2b_zAccountId.out[i];
    }

    out[0] <== b2n_zAccountId_zAccountZoneId.out;


    // 1) nUtxoIn x originZoneId + nUtxoOut x targetZoneId
    component n2b_utxoInOriginZoneId[nUtxoIn];
    for (var j = 0; j < nUtxoIn; j++) {
        n2b_utxoInOriginZoneId[j] = Num2Bits(16);
        n2b_utxoInOriginZoneId[j].in <== utxoInOriginZoneId[j];
    }

    component n2b_utxoOutTargetZoneId[nUtxoOut];
    for (var j = 0; j < nUtxoOut; j++) {
        n2b_utxoOutTargetZoneId[j] = Num2Bits(16);
        n2b_utxoOutTargetZoneId[j].in <== utxoOutTargetZoneId[j];
    }

    var max_nUtxoIn_nUtxoOut = nUtxoIn > nUtxoOut ? nUtxoIn:nUtxoOut;
    component b2n_utxoInOriginZoneId_utxoOutTargetZoneId[max_nUtxoIn_nUtxoOut];

    for (var j = 0; j < max_nUtxoIn_nUtxoOut; j++) {
        b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j] = Bits2Num(32);
        if( j < nUtxoIn && j < nUtxoOut ) {
            for(var i = 0; i < 16; i++) {
                b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[i] <== n2b_utxoOutTargetZoneId[j].out[i];
            }
            for(var i = 0; i < 16; i++) {
                b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[16+i] <== n2b_utxoInOriginZoneId[j].out[i];
            }
        } else {
            if( j < nUtxoIn ) { // j > nUtxoOut ---> utxo-out-targetZoneId - set to be zero - assimetric case
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[i] <== 0;
                }
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[16+i] <== n2b_utxoInOriginZoneId[j].out[i];
                }
            } else {            // j > nUtxoIn  ---> utxo-in-originZoneId -  set to be zero - assimetric case
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[i] <== n2b_utxoOutTargetZoneId[j].out[i];
                }
                for(var i = 0; i < 16; i++) {
                    b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].in[16+i] <== 0;
                }
            }
        }
        out[1+j] <== b2n_utxoInOriginZoneId_utxoOutTargetZoneId[j].out;
    }
}

template DataEscrowElGamalEncryptionPoint(PointsSize) {
    signal input ephemeralRandom;                               // randomness
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key
    signal output ephemeralPubKey[2];                           // ephemeral public-key
    signal output encryptedMessage[PointsSize][2];              // encrypted data

    assert(PointsSize > 0);

    // [0] - Create ephemeral public key
    component ephemeralPubKeyBuilder = EphemeralPubKeysBuilder(PointsSize);
    ephemeralPubKeyBuilder.pubKey[0] <== pubKey[0];
    ephemeralPubKeyBuilder.pubKey[1] <== pubKey[1];
    ephemeralPubKeyBuilder.ephemeralRandom <== ephemeralRandom;

    ephemeralPubKey[0] <== ephemeralPubKeyBuilder.ephemeralPubKey[0][0];
    ephemeralPubKey[1] <== ephemeralPubKeyBuilder.ephemeralPubKey[0][1];

    component drv_mGrY[PointsSize];

    for (var j = 0; j < PointsSize; j++) {
        // ephemeralRandom * pubKey + M
        drv_mGrY[j] = BabyAdd();
        drv_mGrY[j].x1 <== pointMessage[j][0];
        drv_mGrY[j].y1 <== pointMessage[j][1];
        drv_mGrY[j].x2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[j][0];
        drv_mGrY[j].y2 <== ephemeralPubKeyBuilder.ephemeralRandomPubKey[j][1];

        // encrypted data
        encryptedMessage[j][0] <== drv_mGrY[j].xout;
        encryptedMessage[j][1] <== drv_mGrY[j].yout;
    }
}
