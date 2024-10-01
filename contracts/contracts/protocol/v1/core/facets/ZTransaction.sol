// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZTransactionStorageGap.sol";

import "../../verifier/Verifier.sol";

import "./zTransaction/DepositAndWithdrawalHandler.sol";
import "../utils/TransactionChargesHandler.sol";
import "../utils/TransactionNoteEmitter.sol";

import "../libraries/TransactionTypes.sol";
import "../libraries/UtxosInserter.sol";
import "../libraries/NullifierSpender.sol";
import "../libraries/PublicInputGuard.sol";
import "../libraries/TokenTypeAndAddressDecoder.sol";

import "../../../../common/NonReentrant.sol";

/**
 * @title ZTransaction
 * @notice The ZTransaction contract facilitates the execution of transactions involving zAssets,
 * including deposit and withdrawal, and, internal transactions.
 */

contract ZTransaction is
    AppStorage,
    ZTransactionStorageGap,
    Verifier,
    TransactionNoteEmitter,
    TransactionChargesHandler,
    DepositAndWithdrawalHandler,
    NonReentrant
{
    using UtxosInserter for address;
    using PublicInputGuard for address;
    using PublicInputGuard for uint256;
    using TransactionTypes for uint16;
    using TransactionOptions for uint32;
    using NullifierSpender for mapping(bytes32 => uint256);
    using TokenTypeAndAddressDecoder for uint256;

    address internal immutable PANTHER_TREES;

    constructor(
        address pantherTrees,
        address vault,
        address feeMaster,
        address zkpToken
    )
        DepositAndWithdrawalHandler(vault)
        TransactionChargesHandler(feeMaster, zkpToken)
    {
        PANTHER_TREES = pantherTrees;
    }

    /**
     * @notice Executes the main transaction logic for processing deposits and withdrawals of zAssets.
     * @param inputs An array of public input parameters to be passed to the verifier
     * (see MainPublicSignals.sol).
     * @param proof The zero knowledge proof
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param paymasterCompensation The amount to compensate the paymaster for processing the transaction.
     * @param privateMessages The private messages.
     * (see `TransactionNoteEmitter.sol`).
     * @return zAccountUtxoBusQueuePos The position in the UTXO bus queue for the newly created zAccount UTXO.
     * @dev Validates inputs to ensure they meet the required constraints,
     * checks for non-zero public inputs, and verifies creation and spend times.
     * Emits a main transaction note upon successful execution.
     * May revert if any validation fails, including checks on non-zero parameters and valid transaction types.
     */
    function main(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external payable nonReentrant returns (uint256 zAccountUtxoBusQueuePos) {
        // The content of data escrow encrypted messages are checked by the circuit

        _validateExtraInputs(
            inputs[MAIN_EXTRA_INPUT_HASH_IND],
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );

        _checkNonZeroPublicInputs(inputs);

        {
            uint256 creationTime = inputs[MAIN_UTXO_OUT_CREATE_TIME_IND];
            creationTime.validateCreationTime(maxBlockTimeOffset);

            uint256 spendTime = inputs[MAIN_SPEND_TIME_IND];
            spendTime.validateSpendTime(maxBlockTimeOffset);

            uint256 zNetworkChainId = inputs[MAIN_ZNETWORK_CHAIN_ID_IND];
            zNetworkChainId.validateChainId();
        }

        _sanitizePrivateMessage(privateMessages, TT_MAIN_TRANSACTION);

        isSpent.validateAndSpendNullifiers(
            [
                inputs[MAIN_ZASSET_UTXO_IN_NULLIFIER_1_IND],
                inputs[MAIN_ZASSET_UTXO_IN_NULLIFIER_2_IND],
                inputs[MAIN_ZACCOUNT_UTXO_IN_NULLIFIER_IND]
            ]
        );

        uint16 transactionType;
        uint96 miningReward;

        {
            uint96 protocolFee;
            transactionType = TransactionTypes.generateMainTxType(inputs);

            (
                protocolFee,
                miningReward
            ) = accountFeesAndReturnProtocolFeeAndMiningReward(
                feeMasterDebt,
                inputs,
                paymasterCompensation,
                transactionType
            );

            if (transactionType.isInternal()) {
                (, address tokenAddress) = inputs[MAIN_TOKEN_IND]
                    .getTokenTypeAndAddress();
                require(tokenAddress == address(0), ERR_NON_ZERO_TOKEN);
            } else {
                // depost and/or withdraw tx
                // NOTE: This contract expects the Vault will check the token (inputs[4]) to
                // be non-zero only if the tokenType is not native.
                _processDepositAndWithdraw(
                    inputs,
                    transactionType,
                    protocolFee
                );
            }
        }

        {
            uint160 circuitId = circuitIds[TT_MAIN_TRANSACTION];
            verifyOrRevert(circuitId, inputs, proof);
        }

        {
            uint32 zAccountUtxoQueueId;
            uint8 zAccountUtxoIndexInQueue;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = PANTHER_TREES.insertMainUtxos(
                inputs,
                transactionOptions,
                miningReward
            );
            _emitMainNote(
                inputs,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                transactionType,
                privateMessages
            );
        }
    }

    /**
     * @notice Checks that required public inputs are non-zero.
     * @dev Validates specific inputs to prevent zero values which could cause errors.
     * @param inputs An array of public input values to validate.
     */
    function _checkNonZeroPublicInputs(uint256[] calldata inputs) private pure {
        inputs[MAIN_SALT_HASH_IND].validateNonZero(ERR_ZERO_SALT_HASH);

        inputs[MAIN_MAGICAL_CONSTRAINT_IND].validateNonZero(
            ERR_ZERO_MAGIC_CONSTR
        );

        inputs[MAIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND].validateNonZero(
            ERR_ZERO_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );

        inputs[MAIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND].validateNonZero(
            ERR_ZERO_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );
    }

    /**
     * @notice Validates extra inputs
     * @dev Checks the provided inputs against their expected hash to ensure data integrity.
     * @param extraInputsHash The hash of the extra inputs to validate.
     * @param transactionOptions The transaction options provided.
     * @param paymasterCompensation The compensation amount for the paymaster.
     * @param privateMessages Encrypted private messages related to the transaction.
     * @dev Reverts if the provided extraInputsHash does not match the hash of the combined extra inputs.
     */
    function _validateExtraInputs(
        uint256 extraInputsHash,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) private pure {
        bytes memory extraInp = abi.encodePacked(
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );
        extraInputsHash.validateExtraInputHash(extraInp);
    }
}
