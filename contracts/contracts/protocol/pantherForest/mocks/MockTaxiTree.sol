// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../taxiTree/PantherTaxiTree.sol";
import "../../crypto/PoseidonHashers.sol";
import { FIELD_SIZE } from "../../crypto/SnarkConstants.sol";

contract MockTaxiTree is PantherTaxiTree {
    // function simulateUpdateLeaf(
    //     BinaryUpdatableTree calldata tree,
    //     bytes32 newLeaf,
    //     bytes32 oldLeaf,
    //     uint256 leafInd,
    //     bytes32[] calldata siblings
    // ) public returns (bytes32 newRoot) {
    //     updateLeaf(tree, newLeaf, oldLeaf, leafInd, siblings);
    // }

    function hash(bytes32[2] memory input) internal pure returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }
}
