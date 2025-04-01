// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../trees/facets/ForestTree.sol";

contract MockForestTree is ForestTree {
    address public owner;

    constructor(
        address utxoInserter,
        address feeMaster,
        address rewardToken,
        uint8 miningRewardVersion
    ) ForestTree(utxoInserter, feeMaster, rewardToken, miningRewardVersion) {
        owner = msg.sender;
    }

    modifier onlyOwner() override {
        require(msg.sender == owner, "LibDiamond: Must be contract owner");
        _;
    }

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) internal view override {} // solhint-disable-line no-empty-blocks

    function mockSetMiningRewards(address miner, uint256 amount) external {
        miningRewards[miner] = amount;
    }
}
