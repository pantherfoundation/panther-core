// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IPlugin.sol";
import "../interfaces/IBalanceViewer.sol";

import "./VaultLib.sol";
import "./ZAssetUtxoGeneratorLib.sol";
import "./publicSignals/ZSwapPublicSignals.sol";

import "../plugins/PluginDataDecoderLib.sol";

import "../../../common/TransferHelper.sol";
import "../../../common/UtilsLib.sol";
import "../../../common/Constants.sol";
import { LockData } from "../../../common/Types.sol";

library ZSwapLib {
    using UtilsLib for uint256;
    using VaultLib for address;
    using PluginDataDecoderLib for bytes;
    using ZAssetUtxoGeneratorLib for uint256;
    using TransferHelper for address;

    function processSwap(
        address plugin,
        bytes memory data,
        uint256[] calldata inputs
    )
        internal
        returns (bytes32[2] memory zAssetUtxos, uint256 outputAmountScaled)
    {
        // it trusts the caller check if this input parameter is equal to vault address
        address vault = inputs[ZSWAP_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND]
            .safeAddress();

        uint8 existingTokenType = _getTokenType(
            inputs[ZSWAP_EXISTING_TOKEN_IND]
        );
        uint8 incomingTokenType = _getTokenType(
            inputs[ZSWAP_INCOMING_TOKEN_IND]
        );

        vault.unlockAsset(
            LockData(
                existingTokenType,
                inputs[ZSWAP_EXISTING_TOKEN_IND].safeAddress(),
                inputs[ZSWAP_EXISTING_TOKEN_ID_IND],
                plugin,
                inputs[ZSWAP_WITHDRAW_AMOUNT_IND].safe96()
            )
        );

        uint96 outputAmount = _executeSwapAndVerifyOutput(
            plugin,
            vault,
            existingTokenType,
            incomingTokenType,
            inputs,
            data
        );

        uint256 scale = inputs[ZSWAP_INCOMING_ZASSET_SCALE_IND];

        uint256 outputAmountRounded = (outputAmount / scale) * scale;
        outputAmountScaled = outputAmountRounded / scale;

        zAssetUtxos[0] = bytes32(
            inputs[ZSWAP_ZASSET_UTXO_OUT_COMMITMENT_1_IND]
        );
        zAssetUtxos[1] = outputAmountScaled.generateZAssetUtxoCommitment(
            inputs[ZSWAP_ZASSET_UTXO_OUT_COMMITMENT_2_PRIVATE_PART_IND]
        );
    }

    function _executeSwapAndVerifyOutput(
        address plugin,
        address vault,
        uint8 existingTokenType,
        uint8 incomingTokenType,
        uint256[] memory inputs,
        bytes memory swapData
    ) private returns (uint96 _outputAmount) {
        address existingToken = inputs[ZSWAP_EXISTING_TOKEN_IND].safeAddress();
        address incomingToken = inputs[ZSWAP_INCOMING_TOKEN_IND].safeAddress();

        PluginData memory pluginData = PluginData({
            tokenIn: existingToken,
            tokenOut: incomingToken,
            amountIn: inputs[ZSWAP_WITHDRAW_AMOUNT_IND].safe96(),
            tokenType: existingTokenType,
            data: swapData
        });

        uint256 vaultInitialBalance = IBalanceViewer(vault).getBalance(
            incomingTokenType,
            incomingToken,
            inputs[ZSWAP_INCOMING_TOKEN_ID_IND]
        );

        try IPlugin(plugin).execute(pluginData) returns (uint256 outputAmount) {
            _outputAmount = outputAmount.safe96();
        } catch Error(string memory reason) {
            revert(reason);
        }

        uint256 vaultUpdatedBalance = IBalanceViewer(vault).getBalance(
            incomingTokenType,
            incomingToken,
            inputs[ZSWAP_INCOMING_TOKEN_ID_IND]
        );

        uint256 receivedAmountInVault = vaultUpdatedBalance -
            vaultInitialBalance;

        require(_outputAmount != 0, "Zero received amount");

        require(
            _outputAmount == receivedAmountInVault,
            "Unexpected vault balance"
        );
    }

    function _getTokenType(
        uint256 token
    ) private pure returns (uint8 tokenType) {
        // TODO: get TokenType from MSB of token
        address tokenAddress = token.safeAddress();

        tokenType = tokenAddress == NATIVE_TOKEN
            ? NATIVE_TOKEN_TYPE
            : ERC20_TOKEN_TYPE;
    }
}
