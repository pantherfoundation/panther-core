// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../interfaces/ITreeRootUpdater.sol";
import "../zeroTrees/EightLevelZeroTree.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

abstract contract TaxiTree is EightLevelZeroTree {
    function _insert(
        bytes32 leaf
    ) internal pure returns (bytes32 _updatedRoot) {
        // node 0 at level 1 (left node)
        bytes32 node01 = hash([leaf, ZERO_VALUE]);

        // node 1 at level 1 (right node)
        bytes32 node11 = getZeroNodeAtLevel(1);

        _updatedRoot = _calculateRoot(node01, node11);
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

        _updatedRoot = _calculateRoot(node01, node11);
    }

    // TODO: The tree only updates the first 3 leaves atm, shall be updated to use all
    // of the empty leaves
    function _calculateRoot(
        bytes32 node01,
        bytes32 node11
    ) private pure returns (bytes32 _updatedRoot) {
        // node 0 at level 2 (left node)
        bytes32 _hash = hash([node01, node11]);

        for (uint256 i = 2; i < EIGHT_LEVELS; i++) {
            _hash = hash([_hash, getZeroNodeAtLevel(i)]);
        }

        _updatedRoot = _hash;
    }

    function hash(bytes32[2] memory input) private pure returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }
}
