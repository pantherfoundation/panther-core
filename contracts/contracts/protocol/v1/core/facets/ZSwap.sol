// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZSwapStorageGap.sol";

import "../../diamond/utils/Ownable.sol";
import "../../diamond/utils/SelfReentrant.sol";

import "../../verifier/Verifier.sol";

import "../errMsgs/ZSwapErrMsgs.sol";

import "../utils/TransactionChargesHandler.sol";
import "../utils/TransactionNoteEmitter.sol";

import "./zSwap/SwapHandler.sol";

import "../libraries/UtxosInserter.sol";
import "../libraries/NullifierSpender.sol";
import "../libraries/PublicInputGuard.sol";
import "../libraries/ZAssetUtxoGenerator.sol";

/**
 * @title ZSwap
 * @notice The ZSwap contract facilitates the swapping of zAssets within the Panther ecosystem,
 * allowing users to spend zAsset UTXO and create another. It integrates with plugins that handle
 * swap processes.
 */
contract ZSwap is
    AppStorage,
    ZSwapStorageGap,
    Ownable,
    Verifier,
    TransactionNoteEmitter,
    TransactionChargesHandler,
    SelfReentrant
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

    /**
     * @notice Updates the status of a ZSwap plugin.
     * @param plugin The address of the plugin to update.
     * @param status The new status of the plugin (enabled or disabled).
     * @dev Emits a `ZSwapPluginUpdated` event when the plugin status is changed.
     */
    function updatePluginStatus(
        address plugin,
        bool status
    ) external onlyOwner {
        zSwapPlugins[plugin] = status;

        emit ZSwapPluginUpdated(plugin, status);
    }

    /**
     * @notice Swaps a Z-Asset using the provided parameters.
     * @param inputs The public input parameters to be passed to the verifier
     * (see `ZSwapPublicSignals.sol`).
     * @param proof The zero knowledge proof
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param paymasterCompensation The compensation amount for the paymaster.
     * @param swapData The encoded data to proceed with the swap.
     * (see `PluginDataDecoderLib.sol`).
     * @param privateMessages The private message.
     * (see `TransactionNoteEmitter.sol`).
     * @return zAccountUtxoBusQueuePos The position in the UTXO bus queue for the zAccount.
     * @dev Validates inputs, checks non-zero public inputs, sanitizes private messages,
     * validates and spends nullifiers, and processes the swap through the identified plugin.
     */
    function swapZAsset(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes memory swapData,
        bytes calldata privateMessages
    ) external selfReentrant returns (uint256 zAccountUtxoBusQueuePos) {
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

    /**
     * @dev Checks that the public inputs are non-zero.
     * @param inputs The public input parameters to validate.
     */
    function _checkNonZeroPublicInputs(uint256[] calldata inputs) private pure {
        inputs[ZSWAP_SALT_HASH_IND].validateNonZero(ERR_ZERO_SALT_HASH);

        inputs[ZSWAP_MAGICAL_CONSTRAINT_IND].validateNonZero(
            ERR_ZERO_MAGIC_CONSTR
        );

        inputs[ZSWAP_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC_IND]
            .validateNonZero(ERR_ZERO_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC);

        inputs[ZSWAP_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC_IND].validateNonZero(
            ERR_ZERO_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC
        );

        inputs[ZSWAP_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC_IND]
            .validateNonZero(ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC);

        inputs[ZSWAP_KYT_INTERNAL_SIGNED_MESSAGE_HASH_IND].validateNonZero(
            ERR_ZERO_KYT_INTERNAL_SIGNED_MESSAGE_HASH
        );
    }

    /**
     * @notice Validates extra inputs
     * @dev Checks the provided inputs against their expected hash to ensure data integrity.
     * @param extraInputsHash The expected hash of the extra inputs.
     * @param transactionOptions The transaction options to validate.
     * @param paymasterCompensation The compensation for the paymaster to validate.
     * @param swapData The swap data to validate.
     * @param privateMessages The private messages to validate.
     */
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

    /**
     * @dev Retrieves the plugin address from the swap data and checks its validity.
     * @param swapData The data containing the plugin address.
     * @return _plugin The address of the identified plugin.
     * @dev Reverts if the plugin is not known.
     */
    function _getKnownPluginOrRevert(
        bytes memory swapData
    ) private view returns (address _plugin) {
        _plugin = swapData.extractPluginAddress();
        require(zSwapPlugins[_plugin], ERR_UNKNOWN_PLUGIN);
    }
}
