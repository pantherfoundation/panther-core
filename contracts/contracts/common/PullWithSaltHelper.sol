// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
// slither-disable-next-line solc-version
pragma solidity ^0.8.4;

import "./TransferHelper.sol";
import "../protocol/common/vault/StealthExec.sol";
import "../protocol/common/vault/StealthEthPull.sol";

string constant ERR_BALANCE_MISMATCH = "PWS:E01";
string constant ERR_UNEXPECTED_NONZERO_NFT_BALANCE = "PWS:E02";
string constant ERR_UNEXPECTED_OWNER = "PWS:E03";

/// @title PullWithSaltHelper library
/// @dev Helpers for "pulling" tokens from a "stealth" account linked to a "salt".
/// See `StealthExec` and `StealthEthPull` libraries for details on "stealth" accounts.
/// The ERC-20, ERC-721, ERC-721 tokens and the native token (ETH) supported.
library PullWithSaltHelper {
    using StealthExec for bytes32;
    using StealthEthPull for bytes32;
    using TransferHelper for address;

    uint256 private constant ZERO_WEI = 0;

    /// @dev Pull from the address `from` to the `address(this)` the ERC-20 token `amount`.
    /// The `from` should have approved spending of the `amount` by the "stealth" account
    /// deterministically defined by the `salt`.
    function pullWithSaltErc20(
        bytes32 salt,
        address token,
        address from,
        uint256 amount
    ) internal {
        uint256 oldBalance = token.safeBalanceOf(address(this));

        bytes memory callData = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            from,
            address(this),
            amount
        );
        salt.stealthCall(token, callData, ZERO_WEI);

        _matchBalance(amount, oldBalance, token.safeBalanceOf(address(this)));
    }

    /// @dev Pull from the address `from` to the `address(this)` the ERC-721 token.
    /// The `from` should have approved spending of the token by the "stealth" account
    /// deterministically defined by the `salt`.
    function pullWithSaltErc721(
        bytes32 salt,
        address token,
        address from,
        uint256 tokenId
    ) internal {
        require(
            token.safe721OwnerOf(tokenId) != address(this),
            ERR_UNEXPECTED_OWNER
        );

        bytes memory callData = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            from,
            address(this),
            tokenId
        );
        salt.stealthCall(token, callData, ZERO_WEI);

        require(
            token.safe721OwnerOf(tokenId) == address(this),
            ERR_UNEXPECTED_OWNER
        );
    }

    /// @dev Pull from the address `from` to the `address(this)` the ERC-1155 token `amount`.
    /// The `from` should have approved spending of the `amount` by the "stealth" account
    /// deterministically defined by the `salt`.
    function pullWithSaltErc1155(
        bytes32 salt,
        address token,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal {
        uint256 oldBalance = token.safe1155BalanceOf(address(this), tokenId);

        bytes memory callData = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            from,
            address(this),
            tokenId,
            amount,
            new bytes(0)
        );
        salt.stealthCall(token, callData, ZERO_WEI);

        _matchBalance(
            amount,
            oldBalance,
            token.safe1155BalanceOf(address(this), tokenId)
        );
    }

    /// @dev Pull to the `address(this)` the `value` (in Wei) from the "stealth" account
    /// deterministically defined by the `salt`. This account must hold exactly `value`
    /// Wei on its balance.
    function pullEthWithSalt(bytes32 salt, uint256 value) internal {
        uint256 oldBalance = address(this).balance;
        pullEthBalanceWithSalt(salt);
        _matchBalance(value, oldBalance, address(this).balance);
    }

    /// @dev Pull to the `address(this)` the ETH balance the "stealth" account holds.
    /// The "stealth" account is deterministically defined by the `salt`.
    function pullEthBalanceWithSalt(bytes32 salt) internal {
        salt.stealthPullEthBalance();
    }

    function _matchBalance(
        uint256 increase,
        uint256 oldBalance,
        uint256 newBalance
    ) private pure {
        uint256 expValue = newBalance - oldBalance;
        require(increase == expValue, ERR_BALANCE_MISMATCH);
    }
}
