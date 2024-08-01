// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IPlugin.sol";

contract MockUniswapPlugin is IPlugin {
    using SafeERC20 for IERC20;

    // solhint-disable var-name-mixedcase
    address public VAULT;

    constructor(address _vault) {
        VAULT = _vault;
    }

    function execute(
        PluginData calldata pluginData
    ) external payable returns (uint256 amountOut) {
        require(pluginData.amountIn > 0, "Amount in must be greater than zero");
        require(
            pluginData.tokenIn != address(0),
            "Token in address cannot be zero"
        );
        require(
            pluginData.tokenOut != address(0),
            "Token out address cannot be zero"
        );

        amountOut = pluginData.amountIn / 2;
        address tokenOut = pluginData.tokenOut;

        IERC20(tokenOut).safeTransfer(VAULT, amountOut);
    }
}
