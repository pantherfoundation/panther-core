// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./interfaces/IPantherPoolV1.sol";

import "./pantherForest/busTree/BusTree.sol";
import { FIELD_SIZE } from "./crypto/SnarkConstants.sol";
import { ERC20_TOKEN_TYPE } from "../common/Constants.sol";
import { LockData } from "../common/Types.sol";
import "../common/ImmutableOwnable.sol";
import "./crypto/PoseidonHashers.sol";
import "./errMsgs/PantherBusTreeErrMsgs.sol";

contract PantherBusTree is BusTree, ImmutableOwnable {
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    // solhint-disable var-name-mixedcase

    // timestamp of deployment
    uint256 public immutable START_TIME;

    // address of reward token
    address public immutable REWARD_TOKEN;

    // solhint-enable var-name-mixedcase

    // avg number of utxos which can be added per minute
    uint16 public perMinuteUtxosLimit;

    // base reward per each utxo
    uint96 public basePerUtxoReward;

    // keeps track of number of the added utxos
    uint32 public utxoCounter;

    event MinerRewarded(address miner, uint256 reward);

    constructor(
        address owner,
        address rewardToken,
        address _pantherPool,
        address _verifier,
        uint160 _circuitId
    ) ImmutableOwnable(owner) BusTree(_verifier, _circuitId, _pantherPool) {
        require(rewardToken != address(0), ERR_INIT);

        START_TIME = block.timestamp;

        REWARD_TOKEN = rewardToken;
    }

    // TODO: Remove _perMinuteUtxosLimit after Testnet (required for Stage #0..2 only)
    function updateParams(
        uint16 _perMinuteUtxosLimit,
        uint96 _basePerUtxoReward,
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external onlyOwner {
        BusQueues.updateParams(reservationRate, premiumRate, minEmptyQueueAge);

        require(
            _perMinuteUtxosLimit > 0 && _basePerUtxoReward > 0,
            ERR_ZERO_REWARD_PARAMS
        );
        perMinuteUtxosLimit = _perMinuteUtxosLimit;
        basePerUtxoReward = _basePerUtxoReward;
    }

    function rewardMiner(address miner, uint256 reward) internal override {
        LockData memory data = LockData({
            tokenType: ERC20_TOKEN_TYPE,
            token: REWARD_TOKEN,
            tokenId: 0,
            extAccount: miner,
            extAmount: uint96(reward)
        });

        IPantherPoolV1(PANTHER_POOL).unlockAssetFromVault(data);

        emit MinerRewarded(miner, reward);
    }

    function hash(bytes32 left, bytes32 right)
        internal
        pure
        override
        returns (bytes32)
    {
        return PoseidonHashers.poseidonT3([left, right]);
    }

    function getAllowedUtxosAt(uint256 _timestamp, uint256 _utxoCounter)
        public
        view
        returns (uint256 allowedUtxos)
    {
        if (_timestamp < START_TIME) return 0;

        uint256 secs = _timestamp - START_TIME;
        allowedUtxos = (secs * perMinuteUtxosLimit) / 60 seconds - _utxoCounter;
    }

    function addUtxoToBusQueue(bytes32 utxo)
        external
        returns (uint32 queueId, uint8 indexInQueue)
    {
        require(msg.sender == PANTHER_POOL, ERR_UNAUTHORIZED);

        bytes32[] memory utxos = new bytes32[](1);
        utxos[0] = utxo;

        queueId = _nextQueueId == 0 ? 0 : _nextQueueId - 1;
        BusQueue memory busQueue = _busQueues[queueId];
        indexInQueue = busQueue.nUtxos;

        addUtxosToBusQueue(utxos, uint96(basePerUtxoReward));
    }

    // TODO: Remove simulateAddUtxosToBusQueue after Testnet (required for Stage #0..2 only)
    function simulateAddUtxosToBusQueue() external {
        uint256 _counter = uint256(utxoCounter);

        // generating the first utxo
        uint256 utxo = uint256(keccak256(abi.encode(_counter))) % FIELD_SIZE;

        // Generating the utxos length between 1 - 5
        uint256 length = (utxo & 3) + 1;

        if (_counter + length > getAllowedUtxosAt(block.timestamp, _counter))
            return;

        bytes32[] memory utxos = new bytes32[](length);

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

        // overflow risk ignored
        utxoCounter = uint32(_counter);
        uint256 reward = uint256(basePerUtxoReward) * length;

        addUtxosToBusQueue(utxos, uint96(reward));
    }
}
