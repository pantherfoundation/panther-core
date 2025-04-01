// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
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
