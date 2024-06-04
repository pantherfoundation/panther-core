// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

import "../PantherPoolV1.sol";

contract MockPantherPoolV1 is PantherPoolV1 {
    constructor(
        address _owner,
        address zkpToken,
        ForestTrees memory forestTrees,
        address staticTree,
        address vault,
        address zAccountRegistry,
        address prpVoucherGrantor,
        address prpConverter,
        address feeMaster,
        address verifier,
        address pluginRegistry
    )
        PantherPoolV1(
            _owner,
            zkpToken,
            forestTrees,
            staticTree,
            vault,
            zAccountRegistry,
            prpVoucherGrantor,
            prpConverter,
            feeMaster,
            verifier,
            pluginRegistry
        )
    {}

    function internalCacheNewRoot(
        uint256 root
    ) external returns (uint256 cacheIndex) {
        cacheIndex = cacheNewRoot(bytes32(root));
    }

    function mockSpendUtxo(uint256 _utxo, bool _isSpent) external {
        isSpent[bytes32(_utxo)] = _isSpent;
    }
}
