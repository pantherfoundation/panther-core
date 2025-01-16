// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZAccountsRenewalStorageGap.sol";

import "../../diamond/utils/SelfReentrant.sol";

import "../../verifier/Verifier.sol";

import "../utils/TransactionNoteEmitter.sol";
import "../utils/TransactionChargesHandler.sol";

import "../libraries/UtxosInserter.sol";
import "../libraries/NullifierSpender.sol";
import "../libraries/PublicInputGuard.sol";

/**
 * @title ZAccountsRenewal
 * @dev This contract handles the renewal of ZAccounts by spending the old zAccount UTXO and
 * creating a new UTXO. The contract requires activation of the ZAccount before any renewal
 * can take place.
 * The contract also emits relevant events for off-chain logging and
 * tracking of state changes during the renewal process.
 */
// solhint-disable contract-name-camelcase
contract ZAccountsRenewal is
    AppStorage,
    ZAccountsRenewalStorageGap,
    Verifier,
    TransactionNoteEmitter,
    TransactionChargesHandler,
    SelfReentrant
{
    using PublicInputGuard for uint256;
    using UtxosInserter for address;
    using NullifierSpender for mapping(bytes32 => uint256);

    address internal immutable SELF;
    address internal immutable PANTHER_TREES;

    constructor(
        address self,
        address pantherTrees,
        address feeMaster,
        address zkpToken
    ) TransactionChargesHandler(feeMaster, zkpToken) {
        require(pantherTrees != address(0), "init:zero address");

        SELF = self;
        PANTHER_TREES = pantherTrees;
    }

    /**
     * @notice Creates a ZAccount UTXO to renew the zAccount.
     * @param inputs The public input parameters to be passed to verifier.
     * (see `ZAccountActivationPublicSignals.sol`).
     * @param proof The zero knowledge proof
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param paymasterCompensation The compensation for the paymaster.
     * @param privateMessages The private messages.
     * (see `TransactionNoteEmitter.sol`).
     * @return utxoBusQueuePos The position in the UTXO bus queue.
     * @dev It can be executed only after activating the ZAccount. It throws
     * if the ZAccount has not been activated so far or it has been
     * blacklisted.
     */
    function renewZAccount(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external selfReentrant returns (uint256 utxoBusQueuePos) {
        _validateExtraInputs(
            inputs[ZACCOUNT_RENEWAL_EXTRA_INPUT_HASH_IND],
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );

        _checkNonZeroPublicInputs(inputs);

        {
            uint256 creationTime = inputs[
                ZACCOUNT_RENEWAL_UTXO_OUT_CREATE_TIME_IND
            ];
            creationTime.validateCreationTime(maxBlockTimeOffset);
        }

        _validateAndSpendNullifier(inputs);

        _sanitizePrivateMessage(privateMessages, TT_ZACCOUNT_RENEWAL);

        {
            uint160 circuitId = circuitIds[TT_ZACCOUNT_RENEWAL];
            verifyOrRevert(circuitId, inputs, proof);
        }

        uint96 miningReward = accountFeesAndReturnMiningReward(
            feeMasterDebt,
            inputs,
            paymasterCompensation,
            TT_ZACCOUNT_RENEWAL
        );

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            utxoBusQueuePos
        ) = PANTHER_TREES.insertZAccountRenewalUtxos(
            inputs,
            transactionOptions,
            miningReward
        );

        _emitZAccountRenewalNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            privateMessages
        );
    }

    /**
     * @notice Validates extra inputs
     * @dev Checks the provided inputs against their expected hash to ensure data integrity.
     * @param extraInputsHash The hash of the extra inputs to validate.
     * @param transactionOptions Options for the transaction.
     * @param paymasterCompensation The compensation for the paymaster.
     * @param privateMessages Any private messages related to the transaction.
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

    /**
     * @notice Checks that required public inputs for renewal are non-zero.
     * @dev Validates specific inputs to prevent zero values which could cause errors.
     * @param inputs An array of public input values to validate.
     */
    function _checkNonZeroPublicInputs(uint256[] calldata inputs) private pure {
        inputs[ZACCOUNT_RENEWAL_SALT_HASH_IND].validateNonZero(
            "ERR_ZERO_SALT_HASH"
        );
        inputs[ZACCOUNT_RENEWAL_MAGICAL_CONSTRAINT_IND].validateNonZero(
            "ERR_ZERO_MAGIC_CONSTR"
        );

        inputs[ZACCOUNT_RENEWAL_UTXO_OUT_COMMITMENT_IND].validateNonZero(
            "ERR_ZERO_ZACCOUNT_COMMIT"
        );

        inputs[ZACCOUNT_RENEWAL_KYC_SIGNED_MESSAGE_HASH_IND].validateNonZero(
            "ERR_ZERO_KYC_MSG_HASH"
        );
    }

    /**
     * @notice Validates and spends nullifiers for ZAccount activation.
     * @dev Checks the nullifiers to prevent double activation in the same zone and network.
     * @param inputs An array of inputs that include nullifier keys.
     */
    function _validateAndSpendNullifier(uint256[] calldata inputs) private {
        uint256 zAccountNullifier = inputs[
            ZACCOUNT_RENEWAL_UTXO_IN_NULLIFIER_IND
        ];

        isSpent.validateAndSpendNullifier(zAccountNullifier);
    }
}
