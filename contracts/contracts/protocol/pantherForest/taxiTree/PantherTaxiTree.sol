// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../interfaces/ITreeRootGetter.sol";

// is PantherTreesZeros
abstract contract PantherTaxiTree is ITreeRootGetter {
    // Root of root with ZERO trees with depth 6
    function getRoot() external pure returns (bytes32) {
        return
            0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69;
    }
}
