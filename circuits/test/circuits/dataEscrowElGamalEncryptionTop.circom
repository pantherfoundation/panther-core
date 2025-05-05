// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../circuits/templates/dataEscrowElGamalEncryption.circom";
include "../../circuits/templates/utils.circom";

template DataEscrowElGamalEncryptionTop ( ScalarsSize, PointsSize ) {

    signal input ephemeralRandom;                               // randomness
    signal input scalarMessage[ScalarsSize];                    // scalars up to 64 bit data to encrypt
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key (assumed to be priv-key * B8)
    signal output ephemeralPubKey[2];                            // ephemeral public-key

    var EncryptedPointsSize = ScalarsSize + PointsSize;
    signal output encryptedMessage[EncryptedPointsSize][2];      // encrypted data
    signal output encryptedMessageHash;
    signal output hmac;

    var ACTIVE = Active();
    var IGNORE_ANCHORED = NonActive();

    signal rc_ephemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(ephemeralRandom);
    signal rc_scalarMessage[ScalarsSize] <== SnarkFieldTagArray(ScalarsSize)(scalarMessage);
    signal rc_pubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(pubKey);

    component dataEscrowElGamalEncryption = DataEscrowElGamalEncryption(ScalarsSize, PointsSize);
    dataEscrowElGamalEncryption.ephemeralRandom <== rc_ephemeralRandom;
    dataEscrowElGamalEncryption.scalarMessage <== rc_scalarMessage;
    dataEscrowElGamalEncryption.pointMessage <== pointMessage;
    dataEscrowElGamalEncryption.pubKey <== rc_pubKey;
}
