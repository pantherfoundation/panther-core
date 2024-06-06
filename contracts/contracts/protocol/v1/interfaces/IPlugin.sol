// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../plugins/Types.sol";

interface IPlugin {
    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256);
}
