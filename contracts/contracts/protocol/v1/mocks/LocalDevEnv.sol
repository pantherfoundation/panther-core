// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { DEAD_CODE_ADDRESS } from "../../../common/Constants.sol";

contract LocalDevEnv {
    modifier onlyLocalDevEnv() {
        // DEAD_CODE_ADDRESS is supposed (and must) be and unusable address,
        // which eliminate risks of using tx.origin here.
        // solhint-disable-next-line avoid-tx-origin
        require(tx.origin == DEAD_CODE_ADDRESS, "Only allowed in forked env");
        _;
    }
}
