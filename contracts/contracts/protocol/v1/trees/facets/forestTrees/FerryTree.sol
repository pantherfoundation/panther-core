// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { THIRTY_TWO_LEVEL_EMPTY_TREE_ROOT } from "../../utils/zeroTrees/Constants.sol";

// It's supposed to run on the mainnet only.
// It keeps roots of the "Bus" trees on supported networks.
// Bridges keepers are expected to:
// - synchronize "Bus" trees roots (which are leafs of this tree)
// - propagate this tree root to other networks (that results in updating the
// state of the `PantherForest` contracts on supported network).
abstract contract FerryTree {
    // Root of root with ZERO trees with depth 32
    function getFerryTreeRoot() public pure returns (bytes32) {
        return THIRTY_TWO_LEVEL_EMPTY_TREE_ROOT;
    }
}
