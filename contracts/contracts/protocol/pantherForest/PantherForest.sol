// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./busTree/BusTree.sol";
import "./rootHistory/RootHistory.sol";
import "./taxiTree/TaxiTree.sol";

abstract contract PantherForest is TaxiTree, BusTree, RootHistory {
    function hash(bytes32 left, bytes32 right)
        internal
        pure
        virtual
        override
        returns (bytes32);

    function hash(bytes32[4] memory) internal pure virtual returns (bytes32);
}
