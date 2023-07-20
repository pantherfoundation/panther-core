// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { PoseidonT6 } from "./crypto/Poseidon.sol";

// (updating the state of the PantherForest contract on a network).
// It's a one-level quin tree that holds the roots of the following trees:
// - ZAssetTree,
// - ZZonesTree,
// - TrustProvidersKeysList,
// - ZAccountBlacklist,
// - ZNetworksTree
//
// It's supposed to run on the mainnet only.
// Bridges keepers are expected to propagate its root to other networks
abstract contract PantherStaticTree {
    function hash(bytes32[5] memory input) private pure returns (bytes32) {
        return PoseidonT6.poseidon(input);
    }
}
