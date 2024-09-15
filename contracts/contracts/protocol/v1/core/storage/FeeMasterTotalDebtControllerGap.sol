// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import { FEE_MASTER_TOTAL_DEBT_CONTROLLER_GAP } from "./Constants.sol";

abstract contract FeeMasterTotalDebtControllerGap {
    bytes32[FEE_MASTER_TOTAL_DEBT_CONTROLLER_GAP] private _startGap;
}
