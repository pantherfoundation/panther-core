// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../common/Types.sol";

interface IPlugin {
    function exec(PluginData calldata pluginParams) external returns (uint256);
}
