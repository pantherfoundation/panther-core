// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../common/Bytecode.sol";
import { VerifyingKey } from "../common/Types.sol";
import "./pantherVerifier/Verifier.sol";

contract PantherVerifier is Verifier {
    /**
     * @notice Get the verifying key for the specified circuits
     * @param circuitId ID of the circuit
     * @dev circuitId is an address where the key is deployed as bytecode
     * @return Verifying key
     */
    function getVerifyingKey(uint160 circuitId)
        external
        view
        returns (VerifyingKey memory)
    {
        return loadVerifyingKey(circuitId);
    }

    /// @dev It reads the verifying key from bytecode at `address(circuitId)`
    function loadVerifyingKey(uint160 circuitId)
        internal
        view
        virtual
        override
        returns (VerifyingKey memory)
    {
        return
            // Stored key MUST be `abi.encode`d and prepended by 0x00
            abi.decode(
                Bytecode.read(address(circuitId), DATA_OFFSET),
                (VerifyingKey)
            );
    }

    // Keys in deployed bytecode MUST be prepended by 0x00 (STOP opcode)
    uint256 private constant DATA_OFFSET = 1;
}
