// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./interfaces/IPantherPoolV1.sol";
import "./pantherForest/busTree/BusTree.sol";
import "./errMsgs/PantherBusTreeErrMsgs.sol";

import { TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT } from "./pantherForest/zeroTrees/Constants.sol";
import { BUS_TREE_FOREST_LEAF_INDEX } from "./pantherForest/Constants.sol";
import { ERC20_TOKEN_TYPE } from "../../common/Constants.sol";
import { LockData } from "../../common/Types.sol";

/**
 * @title PantherBusTree
 * @author Pantherprotocol Contributors
 * @dev It facilitates the storage of batches of UTXO commitments, effectively queuing the
 * UTXOs, with a maximum capacity of 64 entries, subsequently integrating them into the
 * UTXO Merkle tree during the mining process.
 * Employing zero-knowledge methodologies, this contract optimizes the updating procedure of
 * the Bus tree root. Notably, this root serves as a leaf within the PantherForest merkle tree.
 * Miners possess the capability to compute the new bus tree root and transmit it to the contract,
 * effectively onboarding the queue.
 * Through its inherent knowledge of the Verification key's whereabouts, this contract undertakes
 * the verification process, subsequently updating the corresponding Panther forest leaf.
 */
abstract contract PantherBusTree is BusTree {
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    bytes32 internal constant EMPTY_BUS_TREE_ROOT =
        TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT;

    // address of reward token
    address public immutable REWARD_TOKEN;

    // address of feeMaster contract
    address public immutable FEE_MASTER;

    // timestamp to start adding utxo
    uint32 public busTreeStartTime;

    bytes32[50] private _endGap;

    event MinerRewarded(address miner, uint256 reward);

    constructor(
        address owner,
        address pantherPool,
        address pantherVerifier,
        address feeMaster,
        address rewardToken
    ) BusTree(owner, pantherPool, pantherVerifier) {
        REWARD_TOKEN = rewardToken;
        FEE_MASTER = feeMaster;
    }

    function _initializeBusTree(
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge,
        uint160 circuitId
    ) private {
        busTreeStartTime = uint32(block.timestamp);

        BusQueues.updateParams(reservationRate, premiumRate, minEmptyQueueAge);
        _updateCircuitId(circuitId);
    }

    // Code of `function getBusTreeRoot` let avoid explicit initialization:
    // `busTreeRoot = EMPTY_BUS_TREE_ROOT`.
    // Initial value of storage variables is 0 (which is implicitly set in
    // new storage slots). There is no need for explicit initialization.
    function getBusTreeRoot() public view returns (bytes32) {
        return _busTreeRoot == bytes32(0) ? EMPTY_BUS_TREE_ROOT : _busTreeRoot;
    }

    function updateCircuitId(uint160 circuitId) external onlyOwner {
        _updateCircuitId(circuitId);
    }

    function updateBusTreeParams(
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external onlyOwner {
        BusQueues.updateParams(reservationRate, premiumRate, minEmptyQueueAge);
    }

    /// @dev ZK-circuit public signals:
    /// @param inputs[0] - oldRoot (BusTree root before insertion)
    /// @param inputs[1] - newRoot (BusTree root after insertion)
    /// @param inputs[2] - replacedNodeIndex
    /// @param inputs[3] - newLeafsCommitment (commitment to leafs in batch)
    /// @param inputs[4] - nNonEmptyNewLeafs (non-empty leafs in batch number)
    /// @param inputs[5] - batchRoot (Root of the batch to insert)
    /// @param inputs[6] - branchRoot (BusTree branch root after insertion)
    /// @param inputs[7] - extraInput (Hash of `miner` and `queueId`)
    /// @param inputs[8] - magicalConstraint (non-zero random number)
    function onboardQueue(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    ) external {
        (bytes32 busTreeNewRoot, uint96 reward) = _onboardQueue(
            miner,
            queueId,
            inputs,
            proof
        );
        _busTreeRoot = busTreeNewRoot;
        // Synchronize the sate of `PantherForest` contract
        // Trusted contract - no reentrancy guard needed
        _updateForestRoot(busTreeNewRoot, BUS_TREE_FOREST_LEAF_INDEX);
        // TODO: Account fees
        _rewardMiner(miner, reward);
        // _accountMinerRewards();
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
        bytes32[] memory utxos,
        uint96 reward
    ) public returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue) {
        require(msg.sender == PANTHER_POOL, "");
        require(utxos.length != 0, ERR_EMPTY_UTXOS_ARRAY);

        (firstUtxoQueueId, firstUtxoIndexInQueue) = _addUtxosToBusQueue(
            utxos,
            reward
        );
    }

    // TODO
    // solhint-disable-next-line no-empty-blocks
    function claimReward() external {}

    // TODO
    // solhint-disable-next-line no-empty-blocks
    function _accountMinerRewards() private {}

    // TODO: account reward miner
    function _rewardMiner(address miner, uint256 reward) private {
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

    function _updateForestRoot(
        bytes32 updatedLeaf,
        uint256 leafIndex
    ) internal virtual;
}
