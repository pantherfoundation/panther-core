// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import "../pantherPool/CommitmentGenerator.sol";

contract MockCommitmentGenerator is CommitmentGenerator {
    function internalGenerateCommitment(
        uint256 pubSpendingKeyX,
        uint256 pubSpendingKeyY,
        uint64 scaledAmount,
        uint160 zAssetId,
        uint32 creationTime
    ) external pure returns (bytes32 commitment) {
        return
            generateCommitment(
                pubSpendingKeyX,
                pubSpendingKeyY,
                scaledAmount,
                zAssetId,
                creationTime
            );
    }
}
