// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import { G1Point } from "../../../common/Types.sol";
import "../pantherPool/PubKeyGenerator.sol";

contract MockPubKeyGenerator is PubKeyGenerator {
    function internalGeneratePubSpendingKey(
        uint256 privKey
    ) external view returns (G1Point memory pubKey) {
        return generatePubSpendingKey(privKey);
    }
}
