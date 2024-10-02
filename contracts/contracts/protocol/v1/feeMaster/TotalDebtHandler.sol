// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
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
        uint256 msgValue = token == NATIVE_TOKEN ? msg.value : 0;

        try
            IFeeMasterTotalDebtController(pantherPool)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt{
                value: msgValue
            }(token, netAmount, extAccount)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}

//
