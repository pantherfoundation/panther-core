// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
// slither-disable-next-line solc-version
pragma solidity ^0.8.19;

import "./Types.sol";
import { ERC20_TOKEN_TYPE, ERC1155_TOKEN_TYPE, ERC721_TOKEN_TYPE, NATIVE_TOKEN_TYPE } from "./Constants.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TransferHelper.sol";
import "./PluginCaller.sol";

/// @title PluginHelper
/// @dev Caller methods for interacting with Plugin
library PluginExecutor {
    using TransferHelper for address;
    using CallerWithUint256Result for address;

    /// @dev Get the owner of the ERC-721 token
    function safeExecute(
        address plugin,
        PluginData calldata pData
    ) internal returns (uint256 amount) {
        bytes memory pluginCallData = abi.encodeWithSignature(
            // solhint-disable-next-line max-line-length
            "exec(((uint8,address,uint256,address,uint96),(uint8,address,uint256,address,uint96),bytes))",
            pData
        );
        if (
            pData.lDataIn.tokenType == ERC20_TOKEN_TYPE ||
            pData.lDataIn.tokenType == ERC1155_TOKEN_TYPE ||
            pData.lDataIn.tokenType == ERC721_TOKEN_TYPE ||
            pData.lDataIn.tokenType == NATIVE_TOKEN_TYPE
        ) {
            amount = plugin.callWithUint256Result(pluginCallData);
        } else {
            revert("ERR_UNSUPPRTED_TYPE");
        }
    }
}
