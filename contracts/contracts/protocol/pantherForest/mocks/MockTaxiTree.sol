// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../taxiTree/PantherTaxiTree.sol";
import { PoseidonT3 } from "../../crypto/Poseidon.sol";
import { FIELD_SIZE } from "../../crypto/SnarkConstants.sol";

contract MockTaxiTree {
    // function simulateUpdateLeaf(
    //     BinaryTree calldata tree,
    //     bytes32 newLeaf,
    //     bytes32 oldLeaf,
    //     uint256 leafInd,
    //     bytes32[] calldata siblings
    // ) public returns (bytes32 newRoot) {
    //     updateLeaf(tree, newLeaf, oldLeaf, leafInd, siblings);
    // }
    function hash(bytes32[2] memory input) internal pure returns (bytes32) {
        require(
            uint256(input[0]) < FIELD_SIZE && uint256(input[1]) < FIELD_SIZE,
            "TT:TOO_LARGE_LEAF_INPUT"
        );
        return PoseidonT3.poseidon(input);
    }
}
