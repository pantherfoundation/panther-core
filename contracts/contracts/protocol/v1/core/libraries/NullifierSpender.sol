// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable explicit-types
pragma solidity ^0.8.19;

string constant ERR_ZERO_NULLIFIER = "SN:E1";
string constant ERR_SPENT_NULLIFIER = "SN:E2";

library NullifierSpender {
    function validateAndSpendNullifiers(
        mapping(bytes32 => uint256) storage isSpent,
        uint256[3] memory nullifiers
    ) internal {
        for (uint256 nullifier = 0; nullifier < nullifiers.length; ) {
            validateAndSpendNullifier(isSpent, nullifiers[nullifier]);
            unchecked {
                ++nullifier;
            }
        }
    }

    function validateAndSpendNullifier(
        mapping(bytes32 => uint256) storage isSpent,
        uint256 nullifier
    ) internal {
        bytes32 _nullifier = bytes32(nullifier);
        require(_nullifier > 0, ERR_ZERO_NULLIFIER);

        require(isSpent[_nullifier] == 0, ERR_SPENT_NULLIFIER);
        isSpent[_nullifier] = block.number;
    }
}
