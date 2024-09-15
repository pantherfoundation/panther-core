// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../interfaces/IVerifyingKeyProvider.sol";

import "../../../common/Bytecode.sol";
import { VerifyingKey } from "../../../common/Types.sol";

abstract contract VerifyingKeyProvider is IVerifyingKeyProvider {
    /// @inheritdoc IVerifyingKeyProvider
    function getVerifyingKey(
        uint160 circuitId
    ) external view returns (VerifyingKey memory) {
        return _loadVerifyingKey(circuitId);
    }

    /// @dev It reads the verifying key from bytecode at `address(circuitId)`
    function _loadVerifyingKey(
        uint160 circuitId
    ) internal view virtual returns (VerifyingKey memory) {
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
