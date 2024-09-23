// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../trees/facets/StaticTree.sol";

contract MockStaticTree is StaticTree {
    address public owner;

    constructor(address self) StaticTree(self) {
        owner = msg.sender;
    }

    modifier onlyOwner() override {
        require(msg.sender == owner, "LibDiamond: Must be contract owner");
        _;
    }
}
