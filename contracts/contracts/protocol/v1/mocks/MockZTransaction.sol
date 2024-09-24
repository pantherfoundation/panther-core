// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
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
}
