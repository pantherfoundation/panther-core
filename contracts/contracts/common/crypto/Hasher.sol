// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import "./PoseidonHashers.sol";

/*
 * @dev Poseidon hash functions
 */
abstract contract Hasher {
    function hash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        bytes32[2] memory input;
        input[0] = left;
        input[1] = right;
        return PoseidonT3.poseidon(input);
    }

    function hash(
        bytes32 left,
        bytes32 mid,
        bytes32 right
    ) internal pure returns (bytes32) {
        bytes32[3] memory input;
        input[0] = left;
        input[1] = mid;
        input[2] = right;
        return PoseidonT4.poseidon(input);
    }
}
