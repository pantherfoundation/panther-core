// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/ITreeRootUpdater.sol";
import "../zeroTrees/TwoLevelZeroTree.sol";
import { ZERO_VALUE } from "../zeroTrees/Constants.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

abstract contract TaxiTree is TwoLevelZeroTree {
    function _insert(
        bytes32 leaf
    ) internal pure returns (bytes32 _updatedRoot) {
        // node 0 at level 1 (left node)
        bytes32 node01 = hash([leaf, ZERO_VALUE]);

        // node 1 at level 1 (right node)
        bytes32 node11 = ZERO_NODE;

        _updatedRoot = hash([node01, node11]);
    }

    function _insert(
        bytes32 leaf0,
        bytes32 leaf1,
        bytes32 leaf2
    ) internal pure returns (bytes32 _updatedRoot) {
        // node 0 at level 1 (left node)
        bytes32 node01 = hash([leaf0, leaf1]);

        // node 1 at level 1 (right node)
        bytes32 node11 = hash([leaf2, ZERO_VALUE]);

        _updatedRoot = hash([node01, node11]);
    }

    function hash(bytes32[2] memory input) private pure returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }
}
