// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
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
