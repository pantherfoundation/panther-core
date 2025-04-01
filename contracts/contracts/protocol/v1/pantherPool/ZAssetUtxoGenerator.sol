// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../common/crypto/PoseidonHashers.sol";

abstract contract ZAssetUtxoGenerator {
    function generateZAssetUtxoCommitment(
        uint256 zAssetScaledAmount,
        uint256 zAssetutxoCommitmentPrivatePart
    ) internal pure returns (bytes32) {
        return
            PoseidonHashers.poseidonT3(
                [
                    bytes32(zAssetScaledAmount),
                    bytes32(zAssetutxoCommitmentPrivatePart)
                ]
            );
    }
}
