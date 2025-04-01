// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { MAIN_DEPOSIT_AMOUNT_IND, MAIN_WITHDRAW_AMOUNT_IND } from "../publicSignals/MainPublicSignals.sol";
import "../utils/Types.sol";

library TransactionTypes {
    function generateMainTxType(
        uint256[] calldata inputs
    ) internal pure returns (uint16 txType) {
        uint256 depositAmount = inputs[MAIN_DEPOSIT_AMOUNT_IND];
        uint256 withdrawAmount = inputs[MAIN_WITHDRAW_AMOUNT_IND];
        txType = TT_MAIN_TRANSACTION;

        if (depositAmount > 0) txType |= TF_DEPOSIT_TRANSACTION;
        if (withdrawAmount > 0) txType |= TF_WITHDRAWAL_TRANSACTION;
    }

    function isDeposit(uint16 txType) internal pure returns (bool) {
        return isMain(txType) && (txType & TF_DEPOSIT_TRANSACTION > 0);
    }

    function isWithdrawal(uint16 txType) internal pure returns (bool) {
        return isMain(txType) && (txType & TF_WITHDRAWAL_TRANSACTION > 0);
    }

    function isInternal(uint16 txType) internal pure returns (bool) {
        return txType == TT_MAIN_TRANSACTION;
    }

    function isMain(uint16 txType) internal pure returns (bool) {
        return (txType & TM_CLEAR_FLAGS) == TT_MAIN_TRANSACTION;
    }

    function isActivationOrReactivationOrRenewal(
        uint16 txType
    ) internal pure returns (bool) {
        return
            txType == TT_ZACCOUNT_ACTIVATION ||
            txType == TT_ZACCOUNT_REACTIVATION ||
            txType == TT_ZACCOUNT_RENEWAL;
    }
}
