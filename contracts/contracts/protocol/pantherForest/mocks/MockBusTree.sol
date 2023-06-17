// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../busTree/BusTree.sol";
import { PoseidonT3 } from "../../crypto/Poseidon.sol";
import { FIELD_SIZE } from "../../crypto/SnarkConstants.sol";

contract MockBusTree is BusTree {
    event MinerRewarded(address miner, uint256 reward);

    constructor(address _verifier, uint160 _circuitId)
        BusTree(_verifier, _circuitId)
    {} // solhint-disable-line no-empty-blocks

    function rewardMiner(address miner, uint256 reward) internal override {
        emit MinerRewarded(miner, reward);
    }

    function hash(bytes32 left, bytes32 right)
        internal
        pure
        override
        returns (bytes32)
    {
        require(
            uint256(left) < FIELD_SIZE && uint256(right) < FIELD_SIZE,
            "BT:TOO_LARGE_LEAF_INPUT"
        );
        return PoseidonT3.poseidon([left, right]);
    }

    function simulateAddUtxosToBusQueue(bytes32[] memory utxos, uint96 reward)
        external
    {
        addUtxosToBusQueue(utxos, reward);
    }
}
