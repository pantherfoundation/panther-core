// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/ITreeRootGetter.sol";
import { SIX_LEVEL_EMPTY_TREE_ROOT } from "../zeroTrees/Constants.sol";

// is PantherTreesZeros
abstract contract PantherTaxiTree is ITreeRootGetter {
    // Root of root with ZERO trees with depth 6
    function getRoot() external pure returns (bytes32) {
        return SIX_LEVEL_EMPTY_TREE_ROOT;
    }
}
