// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/ITreeRootUpdater.sol";
import "../zeroTrees/TwoLevelZeroTree.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

abstract contract TaxiTree is TwoLevelZeroTree {
    function _insert(
        bytes32[] memory leafs
    ) internal pure returns (bytes32 _updatedRoot) {
        // node 0 at level 1 (left node)
        bytes32 node01;
        // node 1 at level 1 (right node)
        bytes32 node11;

        if (leafs.length == 1) {
            node01 = hash([leafs[0], ZERO_VALUE]);
            node11 = getZeroNodeAtLevel(1);
        } else if (leafs.length == 2) {
            node01 = hash([leafs[0], leafs[1]]);
            node11 = getZeroNodeAtLevel(1);
        } else if (leafs.length == 3) {
            node01 = hash([leafs[0], leafs[1]]);
            node11 = hash([leafs[2], ZERO_VALUE]);
        } else if (leafs.length == 4) {
            node01 = hash([leafs[0], leafs[1]]);
            node11 = hash([leafs[2], leafs[3]]);
        } else {
            revert("TT:E1");
        }

        _updatedRoot = hash([node01, node11]);
    }

    function hash(bytes32[2] memory input) internal pure returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }
}
