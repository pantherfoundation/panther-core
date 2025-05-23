// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import { G1Point } from "../../../common/Types.sol";
import { ERR_TOO_LARGE_PRIVKEY } from "../errMsgs/PantherPoolErrMsgs.sol";
import { FIELD_SIZE } from "../../../common/crypto/SnarkConstants.sol";
import "../../../common/crypto/BabyJubJub.sol";

abstract contract PubKeyGenerator {
    function generatePubSpendingKey(
        uint256 privKey
    ) internal view returns (G1Point memory pubKey) {
        // [0] - Require
        require(privKey < FIELD_SIZE, ERR_TOO_LARGE_PRIVKEY);
        // [1] - Generate public key
        G1Point memory base8 = G1Point({
            x: BabyJubJub.BASE8_X,
            y: BabyJubJub.BASE8_Y
        });
        pubKey = BabyJubJub.mulPointEscalar(base8, privKey);
    }
}
