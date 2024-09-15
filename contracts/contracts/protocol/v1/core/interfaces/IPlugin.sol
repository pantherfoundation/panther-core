// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../plugins/Types.sol";

interface IPlugin {
    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256);
}
