// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ForestTreeStorageGap.sol";

import "../../diamond/utils/Ownable.sol";
import "../errMsgs/PantherTreesErrMsgs.sol";

import "../utils/PantherPoolAuth.sol";
import "../utils/Constants.sol";

import "./forestTrees/CachedRoots.sol";
import "./forestTrees/TaxiTree.sol";
import "./forestTrees/BusTree.sol";
import "./forestTrees/FerryTree.sol";

import "../../../../common/crypto/PoseidonHashers.sol";

/**
 * @title PantherForest
 * @notice It stores and updates leafs and the root of the Panther Forest Tree.
 * @dev "Panther Forest Tree" is a merkle tree with a single level (leafs) under
 * the root. It has 3 leafs, which are roots of 3 other merkle trees -
 * the "Taxi Tree", the "Bus Tree" and, the "Ferry Tree".
 * (essentially, these 3 trees are subtree of the Panther Forest tree):
 *
 *      Forest Root
 *            |
 *     +------+------+
 *     |      |      |
 *     0      1      2
 *   Taxi    Bus    Ferry
 *   Tree    Tree   Tree
 *   root    root   root
 *
 * Every of 3 trees are controlled by "tree" smart contracts. A "tree" contract
 * must call this contract to update the value of the leaf and the root of the
 * Forest Tree every time the "controlled" tree is updated.
 * It supports a "history" of recent roots, so that users may refer not only to
 * the latest root, but on former roots cached in the history.
 */
contract ForestTree is
    AppStorage,
    ForestTreeStorageGap,
    CachedRoots,
    TaxiTree,
    BusTree,
    FerryTree,
    PantherPoolAuth,
    Ownable
{
    constructor(
        address utxoInserter,
        address feeMaster,
        address rewardToken,
        uint8 miningRewardVersion
    )
        BusTree(feeMaster, rewardToken, miningRewardVersion)
        PantherPoolAuth(utxoInserter)
    {}

    modifier nonZeroUtxosLength(bytes32[] memory utxos) {
        require(utxos.length != 0, ERR_EMPTY_UTXOS_ARRAY);
        _;
    }

    modifier checkPantherTreesRoots(
        uint256 _cachedForestRootIndex,
        bytes32 _forestRoot,
        bytes32 _staticRoot
    ) {
        require(
            isCachedRoot(_forestRoot, _cachedForestRootIndex) &&
                _staticRoot == staticRoot,
            "invalid roots"
        );

        _;
    }

    function getRoots()
        external
        view
        returns (bytes32 _staticRoot, bytes32 _forestRoot)
    {
        _staticRoot = staticRoot;
        _forestRoot = forestRoot;
    }

    function initializeForestTrees(
        uint160 onboardingQueueCircuitId,
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external onlyOwner {
        require(forestRoot == bytes32(0), "PF: Already initialized");

        bytes32 taxiTreeRoot = getTaxiTreeRoot();
        bytes32 busTreeRoot = getBusTreeRoot();
        bytes32 ferryTreeRoot = getFerryTreeRoot();

        _initCacheForestRoot(taxiTreeRoot, busTreeRoot, ferryTreeRoot);

        _initializeBusTree(
            onboardingQueueCircuitId,
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );
    }

    function updateBusQueueRewardParams(
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external onlyOwner {
        _updateBusQueueRewardParams(
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );
    }

    function addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint256 cachedForestRootIndex,
        bytes32 forestRoot,
        bytes32 staticRoot,
        uint96 reward
    )
        external
        onlyPantherPool
        nonZeroUtxosLength(utxos)
        checkPantherTreesRoots(cachedForestRootIndex, forestRoot, staticRoot)
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue)
    {
        // The pool cannot execute this method before this contract is initialized
        (firstUtxoQueueId, firstUtxoIndexInQueue) = _addUtxosToBusQueue(
            utxos,
            reward
        );
    }

    function addUtxosToBusQueueAndTaxiTree(
        bytes32[] memory utxos,
        uint8 numTaxiUtxos,
        uint256 cachedForestRootIndex,
        bytes32 forestRoot,
        bytes32 staticRoot,
        uint96 reward
    )
        external
        onlyPantherPool
        nonZeroUtxosLength(utxos)
        checkPantherTreesRoots(cachedForestRootIndex, forestRoot, staticRoot)
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue)
    {
        (firstUtxoQueueId, firstUtxoIndexInQueue) = _addUtxosToBusQueue(
            utxos,
            reward
        );

        bytes32 taxiTreeNewRoot;

        if (numTaxiUtxos == 1) {
            taxiTreeNewRoot = _addUtxo(utxos[0]);
        } else {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Load the length of the `arr` array
                let arrLength := mload(utxos)

                // Check if we need to modify the length
                if gt(arrLength, numTaxiUtxos) {
                    // Set the new length of the array
                    mstore(utxos, numTaxiUtxos)
                }
            }

            taxiTreeNewRoot = _addUtxos(utxos);
        }

        _cacheNewForestRoot(taxiTreeNewRoot, TAXI_TREE_FOREST_LEAF_INDEX);
    }

    function onboardBusQueue(
        address miner,
        uint32 queueId,
        uint256[] memory inputs,
        SnarkProof memory proof
    ) external {
        // No queue will be exist before initializing

        bytes32 busTreeNewRoot = _onboardQueueAndAccountReward(
            miner,
            queueId,
            inputs,
            proof
        );

        _cacheNewForestRoot(busTreeNewRoot, BUS_TREE_FOREST_LEAF_INDEX);
    }

    /// sends zkp token rewards to miner
    function claimMiningReward(address receiver) external {
        _claimMinerRewards(msg.sender, receiver);
    }

    function claimMiningRewardWithSignature(
        address receiver,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address miner = recoverOperator(receiver, v, r, s);
        _claimMinerRewards(miner, receiver);
    }
}
