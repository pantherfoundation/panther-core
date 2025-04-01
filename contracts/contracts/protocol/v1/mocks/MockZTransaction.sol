// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../core/facets/ZTransaction.sol";

contract MockZTransaction is ZTransaction {
    constructor(
        address pantherTrees,
        address vault,
        address feeMaster,
        address zkpToken
    ) ZTransaction(pantherTrees, vault, feeMaster, zkpToken) {}

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) internal view override {} // solhint-disable-line no-empty-blocks

    function getPantherTree() external view returns (address) {
        return PANTHER_TREES;
    }

    function internalIsSpent(
        uint256 nullifier
    ) external view returns (uint256) {
        return isSpent[bytes32(nullifier)];
    }

    function internalfeeMasterDebt(
        address token
    ) external view returns (uint256) {
        return feeMasterDebt[token];
    }
}
