// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import { ERC20_TOKEN_TYPE, ERC721_TOKEN_TYPE, ERC1155_TOKEN_TYPE, NATIVE_TOKEN_TYPE } from "../common/Constants.sol";
import { LockData, SaltedLockData } from "../common/Types.sol";
import "../common/ImmutableOwnable.sol";
import "../common/TransferHelper.sol";
import "../common/PullWithSaltHelper.sol";
import "../common/UtilsLib.sol";
import "./errMsgs/VaultErrMsgs.sol";
import "./interfaces/IVault.sol";
import "./vault/OnERC1155Received.sol";
import "./vault/OnERC721Received.sol";
import "./vault/EthEscrow.sol";

/**
 * @title Vault
 * @author Pantherprotocol Contributors
 * @notice Holder of assets (tokens) for `PantherPool` contract
 * @dev It transfers assets from user to itself (Lock) and vice versa (Unlock).
 * `PantherPool` is assumed to be the only `owner` who is authorized to trigger
 * locking/unlocking assets.
 */
contract Vault is
    ImmutableOwnable,
    OnERC721Received,
    OnERC1155Received,
    EthEscrow,
    IVault
{
    using TransferHelper for address;
    using TransferHelper for address payable;
    using PullWithSaltHelper for bytes32;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _owner) ImmutableOwnable(_owner) {
        // Proxy-friendly: no storage initialization
    }

    // For functions `lockAsset`, `lockAssetWithSalt` and `UnlockAsset`
    // the caller (owner) MUST care of reentrancy guard.
    // If an adversarial "token" this contract calls re-enters directly,
    // `onlyOwner` will revert as `msg.sender` won't be `owner`.

    /// @inheritdoc IVault
    function lockAssetWithSalt(
        SaltedLockData calldata slData
    ) external payable override onlyOwner {
        LockData memory lData = _desaltLockData(slData);
        _checkLockData(lData);

        bytes32 salt = slData.salt;
        if (lData.tokenType == NATIVE_TOKEN_TYPE) {
            if (msg.value == 0) {
                // ETH supposed to be in the escrow - pull it from there
                pullEthFromEscrow(salt, lData.extAccount, lData.extAmount);
            }
            // if msg.value == !0, then ETH is in the contract balance already.
            // BUT the calling code must ensure it is the depositor who sends non-zero
            // msg.value (we can't check it here: inside this function, the owner is
            // msg.sender, not the depositor), like this:
            // require(msg.value == 0 || msg.sender == lData.extAccount);
        } else if (lData.tokenType == ERC20_TOKEN_TYPE) {
            salt.pullWithSaltErc20(
                lData.token,
                lData.extAccount,
                lData.extAmount
            );
        } else if (lData.tokenType == ERC721_TOKEN_TYPE) {
            salt.pullWithSaltErc721(
                lData.token,
                lData.extAccount,
                lData.tokenId
            );
        } else if (lData.tokenType == ERC1155_TOKEN_TYPE) {
            salt.pullWithSaltErc1155(
                lData.token,
                lData.extAccount,
                lData.tokenId,
                lData.extAmount
            );
        } else revert(ERR_INVALID_TOKEN_TYPE);

        emit Locked(lData);
        emit SaltUsed(salt);
    }

    /// @inheritdoc IVault
    function lockAsset(LockData calldata lData) external override onlyOwner {
        _checkLockData(lData);

        if (lData.tokenType == ERC20_TOKEN_TYPE) {
            // Owner, who only may call this code, is trusted to protect
            // against "Arbitrary from in transferFrom" vulnerability
            // slither-disable-next-line arbitrary-send-erc20,reentrancy-benign,reentrancy-events
            lData.token.safeTransferFrom(
                lData.extAccount,
                address(this),
                lData.extAmount
            );
        } else if (lData.tokenType == ERC721_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            lData.token.erc721SafeTransferFrom(
                lData.tokenId,
                lData.extAccount,
                address(this)
            );
        } else if (lData.tokenType == ERC1155_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            lData.token.erc1155SafeTransferFrom(
                lData.extAccount,
                address(this),
                lData.tokenId,
                uint256(lData.extAmount),
                new bytes(0)
            );
        } else {
            revert(ERR_INVALID_TOKEN_TYPE);
        }
        emit Locked(lData);
    }

    /// @inheritdoc IVault
    function unlockAsset(LockData calldata lData) external override onlyOwner {
        _checkLockData(lData);

        if (lData.tokenType == NATIVE_TOKEN_TYPE) {
            payable(lData.extAccount).safeTransferETH(lData.extAmount);
        } else if (lData.tokenType == ERC20_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            lData.token.safeTransfer(lData.extAccount, lData.extAmount);
        } else if (lData.tokenType == ERC721_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            lData.token.erc721SafeTransferFrom(
                lData.tokenId,
                address(this),
                lData.extAccount
            );
        } else if (lData.tokenType == ERC1155_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            lData.token.erc1155SafeTransferFrom(
                address(this),
                lData.extAccount,
                lData.tokenId,
                lData.extAmount,
                new bytes(0)
            );
        } else {
            revert(ERR_INVALID_TOKEN_TYPE);
        }
        emit Unlocked(lData);
    }

    function _checkLockData(LockData memory lData) private view {
        require(lData.extAmount > 0, ERR_ZERO_EXT_AMOUNT);
        require(lData.extAccount != address(0), ERR_ZERO_EXT_ACCOUNT_ADDR);

        if (lData.tokenType == NATIVE_TOKEN_TYPE) {
            require(lData.token == address(0), ERR_NONZERO_LOCK_TOKEN_ADDR);
            require(lData.tokenId == 0, ERR_NONZERO_LOCK_TOKEN_ID);
            require(
                msg.value == 0 || msg.value == lData.extAmount,
                ERR_MISMATCHING_MSG_VALUE
            );
            return;
        }

        // Here the token can't be ETH (with `address` to be 0)
        require(msg.value == 0, ERR_NON_ZERO_MSG_VALUE);
        require(lData.token != address(0), ERR_ZERO_LOCK_TOKEN_ADDR);

        if (lData.tokenType == ERC20_TOKEN_TYPE) {
            require(lData.tokenId == 0, ERR_NONZERO_LOCK_TOKEN_ID);
            return;
        }

        if (lData.tokenType == ERC721_TOKEN_TYPE) {
            require(lData.extAmount == 1, ERR_UNEXPECTED_NFT_AMOUNT);
            return;
        }

        // Here, ERC-1155 may be the only remaining supported token type
        require(lData.tokenType == ERC1155_TOKEN_TYPE, ERR_INVALID_TOKEN_TYPE);
    }

    function _desaltLockData(
        SaltedLockData memory saltedData
    ) private pure returns (LockData memory lData) {
        lData = LockData(
            saltedData.tokenType,
            saltedData.token,
            saltedData.tokenId,
            saltedData.extAccount,
            UtilsLib.safe96(saltedData.extAmount)
        );
    }
}
