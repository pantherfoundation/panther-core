// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/FeeMasterTotalDebtControllerGap.sol";

import "../interfaces/IFeeMasterTotalDebtController.sol";

import { NATIVE_TOKEN, NATIVE_TOKEN_TYPE, ERC20_TOKEN_TYPE } from "../../../../common/Constants.sol";
import "../../../../common/UtilsLib.sol";
import "../libraries/VaultExecutor.sol";

import "../../diamond/utils/Ownable.sol";

contract FeeMasterTotalDebtController is
    AppStorage,
    FeeMasterTotalDebtControllerGap,
    Ownable,
    IFeeMasterTotalDebtController
{
    using VaultExecutor for address;
    using UtilsLib for uint256;

    address public immutable VAULT;
    address public immutable FEE_MASTER;

    /**
     * @dev Constructor sets vault and fee master contract addresses.
     * @param feeMaster Address of the fee master contract responsible for fee calculations.
     * @param vault Address of the vault contract responsible for holding assets.
     */
    constructor(address vault, address feeMaster) {
        require(
            vault != address(0) && feeMaster != address(0),
            "init:zero address"
        );

        VAULT = vault;
        FEE_MASTER = feeMaster;
    }

    /**
     * @notice Adjusts vault assets based on net amount and updates fee master debt.
     * @dev Only callable by the fee master contract.
     * @param token Address of the token being adjusted.
     * @param netAmount Net amount of tokens being locked/unlocked.
     * @param extAccount External account affected by the transaction.
     */
    function adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address token,
        int256 netAmount,
        address extAccount
    ) external payable {
        require(msg.sender == FEE_MASTER, "unauthorized");

        uint8 tokenType = token == NATIVE_TOKEN
            ? NATIVE_TOKEN_TYPE
            : ERC20_TOKEN_TYPE;

        LockData memory data = LockData({
            tokenType: tokenType,
            token: token,
            tokenId: 0,
            extAccount: extAccount,
            extAmount: netAmount > 0
                ? uint256(netAmount).safe96()
                : uint256(-netAmount).safe96()
        });

        if (netAmount > 0) {
            _lockAssetAndIncreaseFeeMasterDebt(data);
        }

        if (netAmount < 0) {
            _unlockAssetAndDecreaseFeeMasterDebt(data);
        }
    }

    /**
     * @dev Internal function to lock asset and increase fee master debt.
     * @param data Lock data specifying token, amount, and external account.
     */
    function _lockAssetAndIncreaseFeeMasterDebt(LockData memory data) private {
        address token = data.token;

        feeMasterDebt[token] += data.extAmount;

        VAULT.lockAsset(data);
    }

    /**
     * @dev Internal function to unlock asset and decrease fee master debt.
     * @param data Unlock data specifying token, amount, and external account.
     */
    function _unlockAssetAndDecreaseFeeMasterDebt(
        LockData memory data
    ) private {
        address token = data.token;

        feeMasterDebt[token] -= data.extAmount;

        VAULT.unlockAsset(data);
    }
}
