// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
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
