// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../busTree/BusTree.sol";
import { PoseidonT3 } from "../../crypto/Poseidon.sol";
import { FIELD_SIZE } from "../../crypto/SnarkConstants.sol";
import { DEAD_CODE_ADDRESS } from "../../../common/Constants.sol";
import "../../mocks/LocalDevEnv.sol";

contract MockBusTree is BusTree, LocalDevEnv {
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    // solhint-disable var-name-mixedcase

    // avg utxos which can be added per minute
    uint256 public immutable AVG_UTXOS_PER_MINUTE;

    // max number of utxos to be added
    uint256 public immutable UTXO_LIMIT;

    // base reward per each utxo
    uint256 public immutable BASE_REWARD_PER_UTXO;

    // timestamp of deployment
    uint256 public immutable START_TIME;

    // solhint-enable var-name-mixedcase

    // keeps track of number of the added utxos
    uint256 public utxoCounter;

    event MinerRewarded(address miner, uint256 reward);

    constructor(
        address _verifier,
        uint160 _circuitId,
        uint256 _avgUtxosPerMinute,
        uint256 _utxoLimit,
        uint256 _baseRewardPerUtxo
    ) BusTree(_verifier, _circuitId) {
        require(
            _avgUtxosPerMinute > 0 && _utxoLimit > 0 && _baseRewardPerUtxo > 0,
            "init: zero value"
        );

        AVG_UTXOS_PER_MINUTE = _avgUtxosPerMinute;
        UTXO_LIMIT = _utxoLimit;
        BASE_REWARD_PER_UTXO = _baseRewardPerUtxo;

        START_TIME = block.timestamp;
    }

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

    function getAllowedUtxosAt(uint256 _timestamp, uint256 _utxoCounter)
        public
        view
        returns (uint256 allowedUtxos)
    {
        if (_timestamp < START_TIME) return 0;

        allowedUtxos =
            ((_timestamp - START_TIME) / 60 seconds) *
            AVG_UTXOS_PER_MINUTE -
            _utxoCounter;
    }

    function simulateAddUtxosToBusQueue() external {
        uint256 _counter = utxoCounter;

        // generating the first utxo
        uint256 utxo = uint256(keccak256(abi.encode(_counter))) % FIELD_SIZE;

        // Generating the utxos length between 1 - 5
        uint256 length = (utxo & 3) + 1;

        if (_counter + length > getAllowedUtxosAt(block.timestamp, _counter))
            return;

        bytes32[] memory utxos;

        // adding the first commitment
        utxos[0] = bytes32(utxo);
        _counter++;

        // adding the rest of commitment
        for (uint256 i = 1; i < length; ) {
            utxos[i] = bytes32(
                uint256(keccak256(abi.encode(_counter))) % FIELD_SIZE
            );

            unchecked {
                i++;
                _counter++;
            }
        }

        utxoCounter = _counter;
        uint256 reward = BASE_REWARD_PER_UTXO * length;

        addUtxosToBusQueue(utxos, uint96(reward));
    }

    function simulateAddGivenUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 reward
    ) external onlyLocalDevEnv {
        addUtxosToBusQueue(utxos, reward);
    }

    function simulateAddBusQueueReward(uint32 queueId, uint96 extraReward)
        external
        onlyLocalDevEnv
    {
        addBusQueueReward(queueId, extraReward);
    }

    function internalUpdateParams(uint16 reservationRate, uint16 premiumRate)
        external
        onlyLocalDevEnv
    {
        updateParams(reservationRate, premiumRate);
    }

    function simulateSetBusQueueAsProcessed(uint32 queueId)
        external
        onlyLocalDevEnv
        returns (
            bytes32 commitment,
            uint8 nUtxos,
            uint96 reward
        )
    {
        return setBusQueueAsProcessed(queueId);
    }
}
