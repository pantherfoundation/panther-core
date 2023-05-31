// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./BusQueues.sol";
import "../../interfaces/IPantherVerifier.sol";

abstract contract BusTree is BusQueues {
    IPantherVerifier public immutable verifier;
    uint160 public immutable circuitId;

    bytes32 public busRoot;
    uint256 public nLeafs;

    event BusRootUpdated(bytes32 busNewRoot);

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

        uint256 reward = markQueueAsOnboarded(queueId, _nLeafs);
        nLeafs = _nLeafs + QUEUE_SIZE;
        busRoot = busNewRoot;
        emit BusRootUpdated(busNewRoot);
        rewardMiner(miner, reward);

        // Public input signals
        uint256[] memory input = new uint256[](5);
        // newLeafsCommitment
        input[0] = uint256(busQueues[queueId].commitment);
        // oldRoot
        input[1] = uint256(busRoot);
        // replacedNodeIndex (equivalent to `_nLeafs / QUEUE_SIZE`)
        input[2] = _nLeafs >> QUEUE_SIZE_BIT;
        // newRoot
        input[3] = uint256(busNewRoot);
        // extraInput
        input[4] = uint256(uint160(miner));

        require(verifier.verify(circuitId, input, proof), "BT:FAILED_PROOF");
    }

    function rewardMiner(address miner, uint256 reward) internal virtual;
}
