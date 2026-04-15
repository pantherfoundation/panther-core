// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../core/interfaces/IFeeMasterTotalDebtController.sol";
import { NATIVE_TOKEN } from "../../../common/Constants.sol";

library TotalDebtHandler {
    function adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address pantherPool,
        address token,
        int256 netAmount,
        address extAccount
    ) internal {
        // NOTE: Since FeeMaster already knows that ERC20 and native tokens will be
        // locked or unlocked to the Vault, we don't provide the tokenType.
        // PantherPoolV1 (aka FeeMasterTotalDebtController) determines whether the token is
        // native or ERC20 based on its address.
        uint256 nativeValue = token == NATIVE_TOKEN ? msg.value : 0;
        _adjustVaultAssets(
            pantherPool,
            token,
            netAmount,
            extAccount,
            nativeValue
        );
    }

    function adjustVaultAssetsAndUpdateTotalFeeMasterDebtWithValue(
        address pantherPool,
        address token,
        int256 netAmount,
        address extAccount,
        uint256 nativeValue
    ) internal {
        _adjustVaultAssets(
            pantherPool,
            token,
            netAmount,
            extAccount,
            nativeValue
        );
    }

    function _adjustVaultAssets(
        address pantherPool,
        address token,
        int256 netAmount,
        address extAccount,
        uint256 nativeValue
    ) private {
        try
            IFeeMasterTotalDebtController(pantherPool)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt{
                value: nativeValue
            }(token, netAmount, extAccount)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}

//
