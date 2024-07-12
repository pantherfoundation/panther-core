// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./IUtxoInserter.sol";
import { SnarkProof } from "../../../common/Types.sol";

interface IPantherTrees is IUtxoInserter {
    function updateStaticRoot(bytes32 updatedLeaf, uint256 leafIndex) external;

    function onboardBusQueue(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    ) external;

    function claimMiningReward(address receiver) external;

    function claimMiningRewardWithSignature(
        address receiver,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
