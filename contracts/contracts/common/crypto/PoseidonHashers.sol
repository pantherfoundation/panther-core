// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import { FIELD_SIZE } from "./SnarkConstants.sol";
import "./Poseidon.sol";

library PoseidonHashers {
    string private constant ERR_INPUT_NOT_IN_FIELD =
        "PoseidonHasher: input not in field";

    function poseidonT3(
        bytes32[2] memory input
    ) internal pure returns (bytes32) {
        require(
            uint256(input[0]) < FIELD_SIZE && uint256(input[1]) < FIELD_SIZE,
            ERR_INPUT_NOT_IN_FIELD
        );
        return PoseidonT3.poseidon(input);
    }

    function poseidonT4(
        bytes32[3] memory input
    ) internal pure returns (bytes32) {
        require(
            uint256(input[0]) < FIELD_SIZE &&
                uint256(input[1]) < FIELD_SIZE &&
                uint256(input[2]) < FIELD_SIZE,
            ERR_INPUT_NOT_IN_FIELD
        );
        return PoseidonT4.poseidon(input);
    }

    function poseidonT5(
        bytes32[4] memory input
    ) internal pure returns (bytes32) {
        require(
            uint256(input[0]) < FIELD_SIZE &&
                uint256(input[1]) < FIELD_SIZE &&
                uint256(input[2]) < FIELD_SIZE &&
                uint256(input[3]) < FIELD_SIZE,
            ERR_INPUT_NOT_IN_FIELD
        );
        return PoseidonT5.poseidon(input);
    }

    function poseidonT6(
        bytes32[5] memory input
    ) internal pure returns (bytes32) {
        require(
            uint256(input[0]) < FIELD_SIZE &&
                uint256(input[1]) < FIELD_SIZE &&
                uint256(input[2]) < FIELD_SIZE &&
                uint256(input[3]) < FIELD_SIZE &&
                uint256(input[4]) < FIELD_SIZE,
            ERR_INPUT_NOT_IN_FIELD
        );
        return PoseidonT6.poseidon(input);
    }
}
