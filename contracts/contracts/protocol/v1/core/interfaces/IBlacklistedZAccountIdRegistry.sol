// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IBlacklistedZAccountIdRegistry {
    function addZAccountIdToBlacklist(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] memory proofSiblings
    ) external returns (bytes32 _updatedRoot);

    function removeZAccountIdFromBlacklist(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] memory proofSiblings
    ) external returns (bytes32 _updatedRoot);
}
