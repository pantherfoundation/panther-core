// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../pantherForest/interfaces/ITreeRootUpdater.sol";
import "../pantherForest/interfaces/ITreeRootGetter.sol";

contract MockTreeRootGetterAndUpdater is ITreeRootUpdater {
    address public immutable STATIC_TREE;

    constructor(address staticTree) {
        STATIC_TREE = staticTree;
    }

    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        ITreeRootUpdater(STATIC_TREE).updateRoot(updatedLeaf, leafIndex);
    }

    function getRoot() external view returns (bytes32) {
        return ITreeRootGetter(STATIC_TREE).getRoot();
    }
}
