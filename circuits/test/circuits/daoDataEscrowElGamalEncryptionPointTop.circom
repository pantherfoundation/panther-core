//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../circuits/templates/dataEscrowElGamalEncryption.circom";
include "../../circuits/templates/utils.circom";

template DataEscrowElGamalEncryptionPointTop ( PointsSize ) {

    signal input ephemeralRandom;                               // randomness
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key
    signal output ephemeralPubKey[2];                            // ephemeral public-key
    signal output encryptedMessage[PointsSize][2];               // encrypted data

    var ACTIVE = Active();

    signal rc_ephemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(ephemeralRandom);
    // signal rc_pointMessage[1] <== pointMessage;
    // signal rc_pubKey[2] <== pubKey;

    component dataEscrowElGamalEncryptionPoint = DataEscrowElGamalEncryptionPoint(PointsSize);

    dataEscrowElGamalEncryptionPoint.ephemeralRandom <== rc_ephemeralRandom;
    dataEscrowElGamalEncryptionPoint.pointMessage <== pointMessage;
    dataEscrowElGamalEncryptionPoint.pubKey <== pubKey;
}
