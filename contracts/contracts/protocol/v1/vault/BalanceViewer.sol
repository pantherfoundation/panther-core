// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "../interfaces/IBalanceViewer.sol";

import { ERR_INVALID_TOKEN_TYPE } from "../errMsgs/VaultErrMsgs.sol";

import "../../../common/TransferHelper.sol";
import { ERC20_TOKEN_TYPE, ERC721_TOKEN_TYPE, ERC1155_TOKEN_TYPE, NATIVE_TOKEN_TYPE } from "../../../common/Constants.sol";

abstract contract BalanceViewer is IBalanceViewer {
    using TransferHelper for address;

    uint256 private constant ZERO_ERC721_BALANCE = 0;
    uint256 private constant ONE_ERC721_BALANCE = 1;

    function getBalance(
        uint8 tokenType,
        address token,
        uint256 tokenId
    ) external view returns (uint256 balance) {
        if (tokenType == NATIVE_TOKEN_TYPE) {
            require(
                token == address(0) && tokenId == 0,
                "bv: invalid token address and id"
            );
            return balance = _getNativeBalance();
        }

        if (tokenType == ERC20_TOKEN_TYPE) {
            require(tokenId == 0, "bv: invalid token id");
            return balance = _getErc20Balance(token);
        }

        if (tokenType == ERC721_TOKEN_TYPE) {
            return balance = _getErc721Balance(token, tokenId);
        }

        if (tokenType == ERC1155_TOKEN_TYPE) {
            return balance = _getErc1155Balance(token, tokenId);
        }

        revert(ERR_INVALID_TOKEN_TYPE);
    }

    function _getNativeBalance() private view returns (uint256) {
        return address(this).safeContractBalance();
    }

    function _getErc20Balance(address token) private view returns (uint256) {
        return token.safeBalanceOf(address(this));
    }

    function _getErc721Balance(
        address token,
        uint256 tokenId
    ) private view returns (uint256) {
        return
            token.safe721OwnerOf(tokenId) == address(this)
                ? ONE_ERC721_BALANCE
                : ZERO_ERC721_BALANCE;
    }

    function _getErc1155Balance(
        address token,
        uint256 tokenId
    ) private view returns (uint256) {
        return token.safe1155BalanceOf(address(this), tokenId);
    }
}
