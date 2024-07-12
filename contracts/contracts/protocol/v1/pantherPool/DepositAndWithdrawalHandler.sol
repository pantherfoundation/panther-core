// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./VaultLib.sol";
import "./TransactionTypes.sol";
import "./publicSignals/MainPublicSignals.sol";

import "../errMsgs/PantherPoolV1ErrMsgs.sol";
import "../../../common/UtilsLib.sol";

/**
 * @title DepositAndWithdrawalHandler
 * @notice Provides methods for processing deposits and withdrawals, including validation
 * of KYT (Know Your Transaction) messages and interaction with the vault.
 * @dev This contract manages the locking and unlocking of assets in the vault based on transaction types.
 */
abstract contract DepositAndWithdrawalHandler {
    using UtilsLib for uint256;
    using VaultLib for address;
    using TransactionTypes for uint16;

    // Mapping of KYT message hashes to block numbers when they were seen
    mapping(bytes32 => uint256) public seenKytMessageHashes;

    // Events
    event SeenKytMessageHash(bytes32 indexed kytMessageHash);

    /**
     * @dev Processes deposit and withdrawal transactions based on provided inputs.
     * @param inputs Public input parameters for the transaction.
     * @param tokenType Type of the token being transacted (native, ERC20, ERC721 or, ERC1155).
     * @param transactionType Type of the transaction (deposit or withdrawal).
     * @param protocolFee Fee deducted for protocol operations, if any.
     */
    function _processDepositAndWithdraw(
        uint256[] calldata inputs,
        uint8 tokenType,
        uint16 transactionType,
        uint96 protocolFee
    ) internal {
        uint96 depositAmount = inputs[MAIN_DEPOSIT_AMOUNT_IND].safe96();
        uint96 withdrawAmount = inputs[MAIN_WITHDRAW_AMOUNT_IND].safe96();

        address token = inputs[MAIN_TOKEN_IND].safeAddress();
        uint256 tokenId = inputs[MAIN_TOKEN_ID_IND];

        if (transactionType.isDeposit()) {
            _processDeposit(
                inputs,
                SaltedLockData(
                    tokenType,
                    token,
                    tokenId,
                    bytes32(inputs[MAIN_SALT_HASH_IND]),
                    inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER_IND]
                        .safeAddress(),
                    depositAmount
                )
            );
        }

        if (transactionType.isWithdrawal()) {
            _processWithdrawal(
                inputs,
                LockData(
                    tokenType,
                    token,
                    tokenId,
                    inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER_IND]
                        .safeAddress(),
                    withdrawAmount
                ),
                protocolFee
            );
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
                .safeAddress() == _getVault(),
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

        _getVault().lockAssetWithSalt(saltedLockData);

        emit SeenKytMessageHash(kytDepositSignedMessageHash);
    }

    function _processWithdrawal(
        uint256[] calldata inputs,
        LockData memory lockData,
        uint96 protocolFee
    ) private {
        uint96 withdrawAmount = inputs[MAIN_WITHDRAW_AMOUNT_IND].safe96();

        // The contract trust that the `FeeMaster` contract validates the `protocolFee`
        if (protocolFee > 0) withdrawAmount -= protocolFee;

        bytes32 kytWithdrawSignedMessageHash = bytes32(
            inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]
        );

        require(
            inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND].safeAddress() ==
                _getVault(),
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

        _getVault().unlockAsset(lockData);

        emit SeenKytMessageHash(kytWithdrawSignedMessageHash);
    }

    /**
     * @dev Retrieves the address of the vault contract.
     * @return Address of the vault used for asset locking/unlocking operations.
     */
    function _getVault() internal view virtual returns (address);
}
