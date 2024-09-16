// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../trees/facets/BlacklistedZAccountsIdsRegistry.sol";

contract MockBlacklistedZAccountsIdsRegistry is
    BlacklistedZAccountsIdsRegistry
{
    constructor(
        address staticTree,
        address pantherPool
    ) BlacklistedZAccountsIdsRegistry(staticTree, pantherPool) {}

    function internalGetZAccountFlagAndLeafIndexes(
        uint24 zAccountId
    ) external pure returns (uint256 flagIndex, uint256 leafIndex) {
        (flagIndex, leafIndex) = _getZAccountFlagAndLeafIndexes(zAccountId);
    }
}
