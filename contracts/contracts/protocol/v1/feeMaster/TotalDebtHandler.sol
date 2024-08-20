// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/ITransactionChargesHandler.sol";
import { NATIVE_TOKEN } from "../../../common/Constants.sol";

library TotalDebtHandler {
    function adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address pantherPool,
        address token,
        int256 netAmount,
        address extAccount
    ) internal {
        uint256 msgValue = token == NATIVE_TOKEN ? msg.value : 0;

        try
            ITransactionChargesHandler(pantherPool)
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
