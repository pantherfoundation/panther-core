//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../circuits/templates/dataEscrowElGamalEncryption.circom";
include "../../circuits/templates/utils.circom";

template DataEscrowElGamalEncryptionPointTop ( PointsSize ) {

    signal input ephemeralRandom;
    signal input pointMessage[PointsSize][2];
    signal input pubKey[2];
    signal output ephemeralPubKey[2];
    signal output encryptedMessage[PointsSize];
    signal output encryptedMessageHash;
    signal output hmac;   

    var ACTIVE = Active();

    signal rc_ephemeralRandom <== BabyJubJubSubOrderTag(ACTIVE)(ephemeralRandom);

    component dataEscrowElGamalEncryptionPoint = DataEscrowElGamalEncryptionPoint(PointsSize);
    dataEscrowElGamalEncryptionPoint.ephemeralRandom <== rc_ephemeralRandom;
    dataEscrowElGamalEncryptionPoint.pointMessage <== pointMessage;
    dataEscrowElGamalEncryptionPoint.pubKey <== pubKey;
}
