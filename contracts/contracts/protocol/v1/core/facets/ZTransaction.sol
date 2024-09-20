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

import "../../../../common/NonReentrant.sol";

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

    address public immutable PANTHER_TREES;

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

    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to MainPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount and zAssets utxo
    /// data.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
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
                require(inputs[MAIN_TOKEN_IND] == 0, ERR_NON_ZERO_TOKEN);
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
