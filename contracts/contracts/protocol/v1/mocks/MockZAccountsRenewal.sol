// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../core/facets/ZAccountsRenewal.sol";

contract MockZAccountsRenewal is ZAccountsRenewal {
    constructor(
        address _self,
        address pantherTrees,
        address feeMaster,
        address zkpToken
    ) ZAccountsRenewal(_self, pantherTrees, feeMaster, zkpToken) {}

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) internal view override {} // solhint-disable-line no-empty-blocks

    function internalIsSpent(
        uint256 nullifier
    ) external view returns (uint256) {
        return isSpent[bytes32(nullifier)];
    }

    function internalFeeMasterDebt(
        address token
    ) external view returns (uint256) {
        return feeMasterDebt[token];
    }
}
