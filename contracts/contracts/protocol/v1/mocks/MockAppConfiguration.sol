// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../core/facets/AppConfiguration.sol";

contract MockAppConfiguration is AppConfiguration {
    address public owner;

    constructor() AppConfiguration() {
        owner = msg.sender;
    }

    modifier onlyOwner() override {
        require(msg.sender == owner, "LibDiamond: Must be contract owner");
        _;
    }

    function spendNullifier(bytes32 nullifier) external {
        isSpent[nullifier] = block.number;
    }
}
