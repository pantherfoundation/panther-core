// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./VaultLib.sol";
import "./TransactionTypes.sol";
import "./publicSignals/MainPublicSignals.sol";

import "../errMsgs/PantherPoolV1ErrMsgs.sol";
import "../../../common/UtilsLib.sol";

abstract contract DepositAndWithdrawalHandler {
    using UtilsLib for uint256;
    using VaultLib for address;
    using TransactionTypes for uint16;

    // kytMessageHash => blockNumber
    mapping(bytes32 => uint256) public seenKytMessageHashes;

    event SeenKytMessageHash(bytes32 indexed kytMessageHash);

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

            _getVault().lockAssetWithSalt(
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

            emit SeenKytMessageHash(kytDepositSignedMessageHash);
        }

        if (transactionType.isWithdrawal()) {
            withdrawAmount = protocolFee > 0
                ? withdrawAmount - protocolFee
                : withdrawAmount;

            bytes32 kytWithdrawSignedMessageHash = bytes32(
                inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND]
            );

            require(
                inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND]
                    .safeAddress() == _getVault(),
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

            _getVault().unlockAsset(
                LockData(
                    tokenType,
                    token,
                    tokenId,
                    inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER_IND]
                        .safeAddress(),
                    withdrawAmount
                )
            );

            emit SeenKytMessageHash(kytWithdrawSignedMessageHash);
        }
    }

    function _getVault() internal view virtual returns (address);
}
