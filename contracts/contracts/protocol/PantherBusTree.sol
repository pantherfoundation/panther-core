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

    // address of reward token
    address public immutable REWARD_TOKEN;

    // TODO: Remove perMinuteUtxosLimit after Testnet (required for Stage #0..2 only)
    // avg number of utxos which can be added per minute
    uint16 public perMinuteUtxosLimit;

    // base reward per each utxo
    uint96 public basePerUtxoReward;

    // keeps track of number of the added utxos
    uint32 public utxoCounter;

    // TODO: Remove lastUtxoSimulationTimestamp after Testnet (required for Stage #0..2 only)
    // keeps track of the timestamp of the latest added utxos
    // lastUtxoUpdateBlockNum
    uint32 public lastUtxoSimulationTimestamp;

    // timestamp to start adding utxo
    uint32 public startTime;

    event MinerRewarded(address miner, uint256 reward);

    constructor(
        address owner,
        address rewardToken,
        address _pantherPool,
        address _verifier,
        uint160 _circuitId
    ) ImmutableOwnable(owner) BusTree(_verifier, _circuitId, _pantherPool) {
        require(rewardToken != address(0), ERR_PBT_INIT);

        REWARD_TOKEN = rewardToken;
    }

    modifier onlyPantherPool() {
        require(msg.sender == PANTHER_POOL, ERR_UNAUTHORIZED);
        _;
    }

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

        if (startTime == 0) startTime = uint32(block.timestamp);

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

        // Trusted contract - no reentrancy guard needed
        IPantherPoolV1(PANTHER_POOL).unlockAssetFromVault(data);

        emit MinerRewarded(miner, reward);
    }

    function hash(
        bytes32 left,
        bytes32 right
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3([left, right]);
    }

    // TODO: Remove getAllowedUtxosAt after Testnet (required for Stage #0..2 only)
    function getAllowedUtxosAt(
        uint256 _timestamp
    ) public view returns (uint256 allowedUtxos) {
        if (_timestamp <= lastUtxoSimulationTimestamp) return 0;

        uint256 secs = _timestamp - lastUtxoSimulationTimestamp;
        // divide before multiply, since fake utxos are allowed to be created per minute (not second)
        return (secs / 60 seconds) * perMinuteUtxosLimit;
    }

    // TODO: add `reward` as a param of `function addUtxoToBusQueue`
    function addUtxoToBusQueue(
        bytes32 utxo
    ) external onlyPantherPool returns (uint32 queueId, uint8 indexInQueue) {
        bytes32[] memory utxos = new bytes32[](1);
        utxos[0] = utxo;
        (queueId, indexInQueue) = addUtxos(utxos, basePerUtxoReward);
    }

    /// @return firstUtxoQueueId ID of the queue which `utxos[0]` was added to
    /// @return firstUtxoIndexInQueue Index of `utxos[0]` in the queue
    /// @dev If the current queue has no space left to add all UTXOs, a part of
    /// UTXOs only are added to the current queue until it gets full, then the
    /// remaining UTXOs are added to a new queue.
    /// Index of any UTXO (not just the 1st one) may be computed as follows:
    /// - index of UTXO in a queue increments by +1 with every new UTXO added,
    ///   (from 0 for the 1st UTXO in a queue up to `QUEUE_MAX_SIZE - 1`)
    /// - number of UTXOs added to the new queue (if there are such) equals to
    ///   `firstUtxoIndexInQueue + utxos[0].length - QUEUE_MAX_SIZE`
    /// - new queue (if created) has ID equal to `firstUtxoQueueId + 1`
    function addUtxosToBusQueue(
        bytes32[] memory utxos
    )
        external
        onlyPantherPool
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue)
    {
        require(utxos.length != 0, ERR_EMPTY_UTXOS_ARRAY);
        uint96 reward = basePerUtxoReward * uint96(utxos.length);

        // TODO: add `reward` as a param and uncomment this line
        // _checkReward(reward, utxos.length);
        (firstUtxoQueueId, firstUtxoIndexInQueue) = addUtxos(utxos, reward);
    }

    function addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 reward
    )
        external
        onlyPantherPool
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue)
    {
        require(utxos.length != 0, ERR_EMPTY_UTXOS_ARRAY);

        _checkReward(reward, utxos.length);

        (firstUtxoQueueId, firstUtxoIndexInQueue) = addUtxos(utxos, reward);
    }

    // TODO: Remove simulateAddUtxosToBusQueue after Testnet (required for Stage #0..2 only)
    function simulateAddUtxosToBusQueue() external {
        uint256 _counter = uint256(utxoCounter);

        // generating the first utxo
        uint256 utxo = uint256(keccak256(abi.encode(_counter))) % FIELD_SIZE;

        // Generating the utxos length between 1 - 4
        uint256 length = (utxo & 3) + 1;

        if (length > getAllowedUtxosAt(block.timestamp)) return;

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
        lastUtxoSimulationTimestamp = uint32(block.timestamp);
        uint256 reward = uint256(basePerUtxoReward) * length;

        addUtxos(utxos, uint96(reward));
    }

    function _checkReward(uint96 reward, uint256 nUtxos) private view {
        uint96 minReward = basePerUtxoReward * uint96(nUtxos);
        require(reward >= minReward, ERR_TOO_SMALL_REWARD);
    }
}
