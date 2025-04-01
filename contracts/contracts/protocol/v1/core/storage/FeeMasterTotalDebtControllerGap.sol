// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import { FEE_MASTER_TOTAL_DEBT_CONTROLLER_GAP } from "./Constants.sol";

abstract contract FeeMasterTotalDebtControllerGap {
    bytes32[FEE_MASTER_TOTAL_DEBT_CONTROLLER_GAP] private _startGap;
}
