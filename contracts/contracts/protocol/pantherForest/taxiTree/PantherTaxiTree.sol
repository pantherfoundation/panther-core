// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../merkleTrees/BinaryUpdatableTree.sol";
import "../zeroTrees/SixLevelZeroTree.sol";
import "../interfaces/ITreeRootGetter.sol";

// is PantherTreesZeros
abstract contract PantherTaxiTree is
    BinaryUpdatableTree,
    SixLevelZeroTree,
    ITreeRootGetter
{
    function getRoot() external pure returns (bytes32) {
        return bytes32(0);
    }
}
