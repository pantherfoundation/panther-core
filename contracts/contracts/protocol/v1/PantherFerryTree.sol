// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// It's supposed to run on the mainnet only.
// It keeps roots of the "Bus" trees on supported networks.
// Bridges keepers are expected to:
// - synchronize "Bus" trees roots (which are leafs of this tree)
// - propagate this tree root to other networks (that results in updating the
// state of the `PantherForest` contracts on supported network).
contract PantherFerryTree {
    // Root of root with ZERO trees with depth 32
    function getRoot() external pure returns (bytes32) {
        return
            0x24ab16594d418ca2e66ca284f56a4cb7039c6d8f8e0c3c8f362cf18b5afa19d0;
    }
}
