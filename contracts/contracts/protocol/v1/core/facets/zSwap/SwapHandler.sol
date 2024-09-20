// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../interfaces/IPlugin.sol";
import "../../../interfaces/IBalanceViewer.sol";

import "../../libraries/VaultExecutor.sol";
import "../../libraries/ZAssetUtxoGenerator.sol";
import "../../libraries/TokenTypeAndAddressDecoder.sol";
import "../../publicSignals/ZSwapPublicSignals.sol";

import "../../../plugins/PluginDataDecoderLib.sol";

import "../../../../../common/TransferHelper.sol";
import "../../../../../common/UtilsLib.sol";
import "../../../../../common/Constants.sol";
import { LockData } from "../../../../../common/Types.sol";

library SwapHandler {
    using UtilsLib for uint256;
    using VaultExecutor for address;
    using PluginDataDecoderLib for bytes;
    using ZAssetUtxoGenerator for uint256;
    using TransferHelper for address;
    using TokenTypeAndAddressDecoder for uint256;

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

        (uint8 existingTokenType, address existingTokenAddress) = inputs[
            ZSWAP_EXISTING_TOKEN_IND
        ].getTokenTypeAndAddress();

        vault.unlockAsset(
            LockData(
                existingTokenType,
                existingTokenAddress,
                inputs[ZSWAP_EXISTING_TOKEN_ID_IND],
                plugin,
                inputs[ZSWAP_WITHDRAW_AMOUNT_IND].safe96()
            )
        );

        uint96 outputAmount = _executeSwapAndVerifyOutput(
            plugin,
            vault,
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
        uint256[] memory inputs,
        bytes memory swapData
    ) private returns (uint96 _outputAmount) {
        (uint8 existingTokenType, address existingTokenAddress) = inputs[
            ZSWAP_EXISTING_TOKEN_IND
        ].getTokenTypeAndAddress();

        (uint8 incomingTokenType, address incomingTokenAddress) = inputs[
            ZSWAP_EXISTING_TOKEN_IND
        ].getTokenTypeAndAddress();

        PluginData memory pluginData = PluginData({
            tokenIn: existingTokenAddress,
            tokenOut: incomingTokenAddress,
            amountIn: inputs[ZSWAP_WITHDRAW_AMOUNT_IND].safe96(),
            tokenType: existingTokenType,
            data: swapData
        });

        uint256 vaultInitialBalance = IBalanceViewer(vault).getBalance(
            incomingTokenType,
            incomingTokenAddress,
            inputs[ZSWAP_INCOMING_TOKEN_ID_IND]
        );

        try IPlugin(plugin).execute(pluginData) returns (uint256 outputAmount) {
            _outputAmount = outputAmount.safe96();
        } catch Error(string memory reason) {
            revert(reason);
        }

        uint256 vaultUpdatedBalance = IBalanceViewer(vault).getBalance(
            incomingTokenType,
            incomingTokenAddress,
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
}
