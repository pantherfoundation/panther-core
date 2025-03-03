// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../libraries/VaultExecutor.sol";
import "../../libraries/TransactionTypes.sol";
import "../../libraries/TokenTypeAndAddressDecoder.sol";
import "../../publicSignals/MainPublicSignals.sol";

import "../../errMsgs/ZTransactionErrMsgs.sol";
import "../../../../../common/UtilsLib.sol";

/**
 * @title DepositAndWithdrawalHandler
 * @notice Provides methods for processing deposits and withdrawals, including validation
 * of KYT (Know Your Transaction) messages and interaction with the vault.
 * @dev This contract manages the locking and unlocking of assets in the vault based on transaction types.
 */
abstract contract DepositAndWithdrawalHandler {
    using UtilsLib for uint256;
    using VaultExecutor for address;
    using TransactionTypes for uint16;
    using TokenTypeAndAddressDecoder for uint256;

    address internal immutable VAULT;

    // Mapping of KYT message hashes to block numbers when they were seen
    mapping(bytes32 => uint256) public seenKytMessageHashes;
    // Events
    event SeenKytMessageHash(bytes32 indexed kytMessageHash);

    constructor(address vault) {
        VAULT = vault;
    }

    /**
     * @dev Processes deposit and withdrawal transactions based on provided inputs.
     * @param inputs Public input parameters for the transaction.
     * @param transactionType Type of the transaction (deposit or withdrawal).
     * @param protocolFee Fee deducted for protocol operations, if any.
     */
    function _processDepositAndWithdraw(
        uint256[] calldata inputs,
        uint16 transactionType,
        uint96 protocolFee
    ) internal {
        uint96 depositAmount = inputs[MAIN_DEPOSIT_AMOUNT_IND].safe96();
        uint96 withdrawAmount = inputs[MAIN_WITHDRAW_AMOUNT_IND].safe96();
        (uint8 tokenType, address tokenAddress) = inputs[
            MAIN_TOKEN_TYPE_AND_ADDRESS_IND
        ].getTokenTypeAndAddress();

        uint256 tokenId = inputs[MAIN_TOKEN_ID_IND];
        if (transactionType.isDeposit()) {
            _processDeposit(
                inputs,
                SaltedLockData(
                    tokenType,
                    tokenAddress,
                    tokenId,
                    bytes32(inputs[MAIN_SALT_HASH_IND]),
                    inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER_IND]
                        .safeAddress(),
                    depositAmount
                )
            );
        }
        if (transactionType.isWithdrawal()) {
            // The contract trust that the `FeeMaster` contract validates the `protocolFee`
            if (protocolFee > 0) withdrawAmount -= protocolFee;
            _processWithdrawal(
                inputs,
                LockData(
                    tokenType,
                    tokenAddress,
                    tokenId,
                    inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER_IND]
                        .safeAddress(),
                    withdrawAmount
                )
            );
        }

        if (transactionType.isInternal()) {
            _validateKytInternalSignedMessageHash(inputs);
        }
    }

    function _processDeposit(
        uint256[] calldata inputs,
        SaltedLockData memory saltedLockData
    ) private {
        bytes32 kytDepositSignedMessageHash = bytes32(
            inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND]
        );
        require(
            inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER_IND]
                .safeAddress() == VAULT,
            ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER
        );
        require(
            kytDepositSignedMessageHash != 0,
            ERR_ZERO_KYT_DEPOSIT_SIGNED_MESSAGE_HASH
        );
        require(
            seenKytMessageHashes[kytDepositSignedMessageHash] == 0,
            ERR_DUPLICATED_KYT_MESSAGE_HASH
        );
        seenKytMessageHashes[kytDepositSignedMessageHash] = block.number;
        VAULT.lockAssetWithSalt(saltedLockData);
        emit SeenKytMessageHash(kytDepositSignedMessageHash);
    }

    function _processWithdrawal(
        uint256[] calldata inputs,
        LockData memory lockData
    ) private {
        bytes32 kytWithdrawSignedMessageHash = bytes32(
            inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]
        );
        require(
            inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND].safeAddress() ==
                VAULT,
            ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER
        );
        require(
            kytWithdrawSignedMessageHash != 0,
            ERR_ZERO_KYT_WITHDRAW_SIGNED_MESSAGE_HASH
        );
        require(
            seenKytMessageHashes[kytWithdrawSignedMessageHash] == 0,
            ERR_DUPLICATED_KYT_MESSAGE_HASH
        );
        seenKytMessageHashes[kytWithdrawSignedMessageHash] = block.number;
        VAULT.unlockAsset(lockData);
        emit SeenKytMessageHash(kytWithdrawSignedMessageHash);
    }

    function _validateKytInternalSignedMessageHash(
        uint256[] calldata inputs
    ) private {
        bytes32 kytInternalSignedMessageHash = bytes32(
            inputs[MAIN_KYT_INTERNAL_SIGNED_MESSAGE_HASH_IND]
        );
        require(
            seenKytMessageHashes[kytInternalSignedMessageHash] == 0,
            ERR_DUPLICATED_KYT_MESSAGE_HASH
        );

        seenKytMessageHashes[kytInternalSignedMessageHash] = block.number;

        emit SeenKytMessageHash(kytInternalSignedMessageHash);
    }
}
