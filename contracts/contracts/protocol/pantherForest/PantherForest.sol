// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./busTree/BusTree.sol";
import "./rootHistory/RootHistory.sol";
import "./taxiTree/TaxiTree.sol";

abstract contract PantherForest is TaxiTree, BusTree, RootHistory {
    function hash(bytes32[2] memory)
        internal
        view
        virtual
        override(BinaryIncrementalTree, DegenerateIncrementalBinaryTree)
        returns (bytes32);

    function hash(bytes32[4] memory) internal view virtual returns (bytes32);
}
