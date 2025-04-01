// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { SnarkProof } from "../../../common/Types.sol";
import "./IVerifier.sol";

interface IVerifier {
    /**
     * @notice Verify the SNARK proof
     * @param circuitId ID of the circuit (it tells which verifying key to use)
     * @param input Public input signals
     * @param proof SNARK proof
     * @return isVerified bool true if proof is valid
     */
    function verify(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) external view returns (bool isVerified);
}
