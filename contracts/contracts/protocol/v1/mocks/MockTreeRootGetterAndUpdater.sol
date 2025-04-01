// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// import "../pantherTrees/interfaces/ITreeRootUpdater.sol";
// import "../pantherTrees/interfaces/ITreeRootGetter.sol";

// contract MockTreeRootGetterAndUpdater is ITreeRootUpdater {
//     address public immutable STATIC_TREE;

//     constructor(address staticTree) {
//         STATIC_TREE = staticTree;
//     }

//     function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
//         ITreeRootUpdater(STATIC_TREE).updateRoot(updatedLeaf, leafIndex);
//     }

//     function getRoot() external view returns (bytes32) {
//         return ITreeRootGetter(STATIC_TREE).getRoot();
//     }
// }
