// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../interfaces/IPantherPoolV1.sol";

import "./busTree/BusTree.sol";

import "../errMsgs/PantherBusTreeErrMsgs.sol";
import { TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT } from "./zeroTrees/Constants.sol";
import { ERC20_TOKEN_TYPE } from "../../../common/Constants.sol";
import { LockData } from "../../../common/Types.sol";

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
        address pantherPool,
        address pantherVerifier,
        address feeMaster,
        address rewardToken
    ) BusTree(pantherPool, pantherVerifier) {
        REWARD_TOKEN = rewardToken;
        FEE_MASTER = feeMaster;
    }

    function _initializeBusTree() internal {
        busTreeStartTime = uint32(block.timestamp);
    }

    // Code of `function getBusTreeRoot` let avoid explicit initialization:
    // `busTreeRoot = EMPTY_BUS_TREE_ROOT`.
    // Initial value of storage variables is 0 (which is implicitly set in
    // new storage slots). There is no need for explicit initialization.
    function getBusTreeRoot() public view returns (bytes32) {
        return _busTreeRoot == bytes32(0) ? EMPTY_BUS_TREE_ROOT : _busTreeRoot;
    }

    function _onboardQueueAndAccountReward(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    ) internal returns (bytes32 busTreeNewRoot) {
        uint96 reward;
        (busTreeNewRoot, reward) = _onboardQueue(miner, queueId, inputs, proof);

        _busTreeRoot = busTreeNewRoot;

        // TODO: Account fees
        _rewardMiner(miner, reward);
        // _accountMinerRewards();
    }

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
}
