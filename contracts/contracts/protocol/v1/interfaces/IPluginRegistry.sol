// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../../common/Types.sol";

interface IPluginRegistry {
    function isRegistered(address plugin) external returns (bool);

    function getCirquitIdByName(
        bytes memory cirquitName
    ) external returns (uint160);

    function getCirquitIdBySigHash(
        bytes4 cirquitIdSigHash
    ) external returns (uint160);

    function requireAllowedUnlocker(address caller) external;
}
