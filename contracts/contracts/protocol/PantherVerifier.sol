// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../common/Bytecode.sol";
import { VerifyingKey } from "../common/Types.sol";
import "./pantherVerifier/Verifier.sol";
import "./interfaces/IPantherVerifier.sol";

contract PantherVerifier is Verifier, IPantherVerifier {
    /// @inheritdoc IPantherVerifier
    function getVerifyingKey(
        uint160 circuitId
    ) external view override returns (VerifyingKey memory) {
        return loadVerifyingKey(circuitId);
    }

    /// @dev It reads the verifying key from bytecode at `address(circuitId)`
    function loadVerifyingKey(
        uint160 circuitId
    ) internal view virtual override returns (VerifyingKey memory) {
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
