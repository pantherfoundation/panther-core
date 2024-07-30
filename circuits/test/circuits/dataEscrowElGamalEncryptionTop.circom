//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../circuits/templates/dataEscrowElGamalEncryption.circom";
include "../../circuits/templates/utils.circom";

template DataEscrowElGamalEncryptionTop ( PaddingPointsSize, ScalarsSize, PointsSize ) {

    signal input ephemeralRandom;                               // randomness
    signal input scalarMessage[ScalarsSize];                    // scalars up to 64 bit data to encrypt
    signal input pointMessage[PointsSize][2];                   // ec points data to encrypt
    signal input pubKey[2];                                     // public key (assumed to be priv-key * B8)
    signal output ephemeralPubKey[2];                            // ephemeral public-key

    var EncryptedPointsSize = PaddingPointsSize + ScalarsSize + PointsSize;
    signal output                  encryptedMessage[EncryptedPointsSize][2];      // encrypted data
    signal output                  encryptedMessageHash;

    var ACTIVE = Active();
    var IGNORE_ANCHORED = NonActive();

    signal rc_ephemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(ephemeralRandom);
    signal rc_scalarMessage[ScalarsSize] <== Uint64TagArray(ACTIVE, ScalarsSize)(scalarMessage);
    signal rc_pubKey[2] <== BabyJubJubSubGroupPointTag(IGNORE_ANCHORED)(pubKey);

    component dataEscrowElGamalEncryption = DataEscrowElGamalEncryption(PaddingPointsSize, ScalarsSize, PointsSize);
    dataEscrowElGamalEncryption.ephemeralRandom <== rc_ephemeralRandom;
    dataEscrowElGamalEncryption.scalarMessage <== rc_scalarMessage;
    dataEscrowElGamalEncryption.pointMessage <== pointMessage;
    dataEscrowElGamalEncryption.pubKey <== rc_pubKey;
}
