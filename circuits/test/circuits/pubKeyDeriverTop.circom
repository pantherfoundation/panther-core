// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "../../circuits/templates/pubKeyDeriver.circom";
include "../../circuits/templates/utils.circom";

template PubKeyDeriverTop () {
    signal input rootPubKey[2];
    signal input random;
    signal output derivedPubKey[2];

    var ACTIVE = Active();

    signal rc_rootPubKey[2] <== BabyJubJubSubGroupPointTag(ACTIVE)(rootPubKey);
    signal rc_random <== BabyJubJubSubOrderTag(ACTIVE)(random);

    component pubKeyDeriver = PubKeyDeriver();
    pubKeyDeriver.rootPubKey <== rc_rootPubKey;
    pubKeyDeriver.random <== rc_random;
}
