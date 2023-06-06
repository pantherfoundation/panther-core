// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./BusQueues.sol";
import "../../interfaces/IPantherVerifier.sol";
import { EMPTY_BUS_TREE_ROOT } from "../zeroTrees/Constants.sol";

abstract contract BusTree is BusQueues {
    IPantherVerifier public immutable verifier;
    uint160 public immutable circuitId;

    bytes32 public busRoot;
    uint256 public nLeafs;

    event BusRootUpdated(bytes32 busNewRoot);

    // @dev It is "proxy-friendly" as it does not change the storage
    constructor(address _verifier, uint160 _circuitId) {
        require(
            IPantherVerifier(_verifier).getVerifyingKey(_circuitId).ic.length >=
                1,
            "BT:INVALID_VK"
        );
        verifier = IPantherVerifier(_verifier);
        circuitId = _circuitId;
    }

    function onboardQueue(
        address miner,
        uint32 queueId,
        bytes32 busNewRoot,
        SnarkProof memory proof
    ) external {
        uint256 _nLeafs = nLeafs;

        // Prepare public input signals
        uint256[] memory input = new uint256[](5);
        // newLeafsCommitment
        input[0] = uint256(busQueues[queueId].commitment);
        // oldRoot
        input[1] = _nLeafs == 0 // With this, busRoot initialization unneeded
            ? uint256(EMPTY_BUS_TREE_ROOT)
            : uint256(busRoot);
        // replacedNodeIndex (equivalent to `_nLeafs / QUEUE_SIZE`)
        input[2] = _nLeafs >> QUEUE_SIZE_BIT;
        // extraInput
        // (miner address anchored to protect against front-runners)
        input[3] = uint256(uint160(miner));
        // newRoot
        input[4] = uint256(busNewRoot);

        // Verify the proof
        require(verifier.verify(circuitId, input, proof), "BT:FAILED_PROOF");

        // Update queues and reward the miner
        busRoot = busNewRoot;
        nLeafs = _nLeafs + QUEUE_SIZE;
        uint256 reward = markQueueAsOnboarded(queueId, _nLeafs);
        emit BusRootUpdated(busNewRoot);

        rewardMiner(miner, reward);
    }

    function rewardMiner(address miner, uint256 reward) internal virtual;
}
