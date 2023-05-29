// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../merkleTrees/BinaryUpdatableTree.sol";
import "../zeroTrees/SixLevelZeroTree.sol";

// is PantherTreesZeros
abstract contract TaxiTree is BinaryUpdatableTree, SixLevelZeroTree {

}
