// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../trees/facets/ProvidersKeysRegistry.sol";

contract MockProvidersKeysRegistry is ProvidersKeysRegistry {
    address public owner;

    constructor(
        address self,
        uint8 keyringVersion
    ) ProvidersKeysRegistry(self, keyringVersion) {
        owner = msg.sender;
    }

    modifier onlyOwner() override {
        require(owner == msg.sender, "LibDiamond: Must be contract owner");
        _;
    }
}
