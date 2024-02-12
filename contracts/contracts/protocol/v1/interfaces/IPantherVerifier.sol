// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { VerifyingKey } from "../../../common/Types.sol";
import "./IVerifier.sol";

interface IPantherVerifier is IVerifier {
    /**
     * @notice Get the verifying key for the specified circuits
     * @param circuitId ID of the circuit
     * @dev circuitId is an address where the key is deployed as bytecode
     * @return Verifying key
     */
    function getVerifyingKey(
        uint160 circuitId
    ) external view returns (VerifyingKey memory);
}
