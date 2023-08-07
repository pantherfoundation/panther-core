// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { FIELD_SIZE } from "./SnarkConstants.sol";
import "./Poseidon.sol";

library PoseidonHashers {
    // TODO: remove duplications (call PoseidonHashers.poseidonT3 instead)
    function poseidonT3(bytes32[2] memory input)
        internal
        pure
        returns (bytes32)
    {
        require(
            uint256(input[0]) < FIELD_SIZE && uint256(input[1]) < FIELD_SIZE,
            "PoseidonHasher: input not in field"
        );
        return PoseidonT3.poseidon(input);
    }

    // TODO: remove duplications (call PoseidonHashers.poseidonT4 instead)
    function poseidonT4(bytes32[3] memory input)
        internal
        pure
        returns (bytes32)
    {
        require(
            uint256(input[0]) < FIELD_SIZE &&
                uint256(input[1]) < FIELD_SIZE &&
                uint256(input[2]) < FIELD_SIZE,
            "PoseidonHasher: input not in field"
        );
        return PoseidonT4.poseidon(input);
    }
}
