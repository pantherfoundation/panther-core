// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
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
