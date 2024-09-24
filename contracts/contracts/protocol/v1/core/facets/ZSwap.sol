// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZSwapStorageGap.sol";

import "../../diamond/utils/Ownable.sol";
import "../../verifier/Verifier.sol";

import "../errMsgs/ZSwapErrMsgs.sol";

import "../utils/TransactionChargesHandler.sol";
import "../utils/TransactionNoteEmitter.sol";

import "./zSwap/SwapHandler.sol";

import "../libraries/UtxosInserter.sol";
import "../libraries/NullifierSpender.sol";
import "../libraries/PublicInputGuard.sol";
import "../libraries/ZAssetUtxoGenerator.sol";

contract ZSwap is
    AppStorage,
    ZSwapStorageGap,
    Ownable,
    Verifier,
    TransactionNoteEmitter,
    TransactionChargesHandler
{
    using SwapHandler for address;
    using UtxosInserter for address;
    using PublicInputGuard for address;
    using PublicInputGuard for uint256;
    using TransactionOptions for uint32;
    using PluginDataDecoderLib for bytes;
    using ZAssetUtxoGenerator for uint256;
    using NullifierSpender for mapping(bytes32 => uint256);

    address internal immutable VAULT;
    address internal immutable PANTHER_TREES;

    // plugin address to boolean
    mapping(address => bool) public zSwapPlugins;

    event ZSwapPluginUpdated(address plugin, bool status);

    constructor(
        address pantherTrees,
        address vault,
        address feeMaster,
        address zkpToken
    ) TransactionChargesHandler(feeMaster, zkpToken) {
        PANTHER_TREES = pantherTrees;
        VAULT = vault;
    }

    function updatePluginStatus(
        address plugin,
        bool status
    ) external onlyOwner {
        zSwapPlugins[plugin] = status;

        emit ZSwapPluginUpdated(plugin, status);
    }

    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to MainPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    /// @param swapData The address of plugin that manages the swap proccess
    /// @param privateMessages the private message that contains zAccount and zAssets utxo
    /// data.
    function swapZAsset(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes memory swapData,
        bytes calldata privateMessages
    ) external returns (uint256 zAccountUtxoBusQueuePos) {
        _validateExtraInputs(
            inputs[ZSWAP_EXTRA_INPUTS_HASH_IND],
            transactionOptions,
            paymasterCompensation,
            swapData,
            privateMessages
        );

        _checkNonZeroPublicInputs(inputs);

        {
            uint256 creationTime = inputs[ZSWAP_UTXO_OUT_CREATE_TIME_IND];
            creationTime.validateCreationTime(maxBlockTimeOffset);

            uint256 spendTime = inputs[ZSWAP_SPEND_TIME_IND];
            spendTime.validateSpendTime(maxBlockTimeOffset);

            uint256 zNetworkChainId = inputs[ZSWAP_ZNETWORK_CHAIN_ID_IND];
            zNetworkChainId.validateChainId();
        }

        _sanitizePrivateMessage(privateMessages, TT_ZSWAP);

        isSpent.validateAndSpendNullifiers(
            [
                inputs[ZSWAP_ZASSET_UTXO_IN_NULLIFIER_1_IND],
                inputs[ZSWAP_ZASSET_UTXO_IN_NULLIFIER_2_IND],
                inputs[ZSWAP_ZACCOUNT_UTXO_IN_NULLIFIER_IND]
            ]
        );

        VAULT.validateVaultAddress(
            inputs[ZSWAP_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND]
        );
        VAULT.validateVaultAddress(
            inputs[ZSWAP_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER_IND]
        );

        {
            uint160 circuitId = circuitIds[TT_ZSWAP];
            verifyOrRevert(circuitId, inputs, proof);
        }

        {
            (
                bytes32[2] memory zAssetUtxos,
                uint256 zAssetAmountScaled
            ) = _getKnownPluginOrRevert(swapData).processSwap(swapData, inputs);

            uint96 miningReward = accountFeesAndReturnMiningReward(
                feeMasterDebt,
                inputs,
                paymasterCompensation,
                TT_ZSWAP
            );

            uint32 zAccountUtxoQueueId;
            uint8 zAccountUtxoIndexInQueue;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = PANTHER_TREES.insertZSwapUtxos(
                inputs,
                zAssetUtxos,
                transactionOptions,
                miningReward
            );

            _emitZSwapNote(
                inputs,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAssetAmountScaled,
                privateMessages
            );
        }
    }

    function _checkNonZeroPublicInputs(uint256[] calldata inputs) private pure {
        inputs[ZSWAP_SALT_HASH_IND].validateNonZero(ERR_ZERO_SALT_HASH);
        inputs[ZSWAP_MAGICAL_CONSTRAINT_IND].validateNonZero(
            ERR_ZERO_MAGIC_CONSTR
        );
    }

    function _validateExtraInputs(
        uint256 extraInputsHash,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes memory swapData,
        bytes calldata privateMessages
    ) private pure {
        bytes memory extraInp = abi.encodePacked(
            transactionOptions,
            paymasterCompensation,
            swapData,
            privateMessages
        );
        extraInputsHash.validateExtraInputHash(extraInp);
    }

    function _getKnownPluginOrRevert(
        bytes memory swapData
    ) private view returns (address _plugin) {
        _plugin = swapData.extractPluginAddress();
        require(zSwapPlugins[_plugin], ERR_UNKNOWN_PLUGIN);
    }
}
