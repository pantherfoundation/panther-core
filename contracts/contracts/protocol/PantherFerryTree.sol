// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./pantherForest/merkleTrees/BinaryUpdatableTree.sol";
import { PoseidonT3 } from "./crypto/Poseidon.sol";

// It's supposed to run on the mainnet only.
// It keeps roots of the "Bus" trees on supported networks.
// Bridges keepers are expected to:
// - synchronize "Bus" trees roots (which are leafs of this tree)
// - propagate this tree root to other networks (that results in updating the
// state of the `PantherForest` contracts on supported network).
contract PantherFerryTree {
    function hash(bytes32[2] memory input) internal pure returns (bytes32) {
        return PoseidonT3.poseidon(input);
    }

    function zeroRoot() public pure override returns (bytes32) {
        return bytes32(0);
    }
}
