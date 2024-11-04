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

/**
 * @title ForestTree
 * @notice This contract stores and updates leaf nodes and the root of the Panther Forest Tree.
 * @dev The Panther Forest Tree is a Merkle tree with a single level (leaves) under the root.
 * It has 3 leaves, which are roots of 3 other Merkle trees: the "Taxi Tree", the "Bus Tree",
 * and the "Ferry Tree". The structure is as follows:
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
 * The contract supports a history of recent roots, allowing users to refer to not only the latest
 * root but also previous roots cached in history.
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
        require(utxos.length != 0, "FT: empty utxos");
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
            "FT: invalid roots"
        );

        _;
    }

    /**
     * @notice Retrieves the current static and forest roots.
     * @return _staticRoot The static root of the forest.
     * @return _forestRoot The current forest root.
     */
    function getRoots()
        external
        view
        returns (bytes32 _staticRoot, bytes32 _forestRoot)
    {
        _staticRoot = staticRoot;
        _forestRoot = forestRoot;
    }

    /**
     * @notice Initializes the Panther Forest Trees with specific parameters.
     * @param onboardingQueueCircuitId The circuit ID for the onboarding queue.
     * @param reservationRate The rate for reservations in the bus queue.
     * @param premiumRate The premium rate for bus queue rewards.
     * @param minEmptyQueueAge The minimum age for an empty bus queue.
     * @dev This function can only be called by the owner and must be called only once.
     */
    function initializeForestTrees(
        uint160 onboardingQueueCircuitId,
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external onlyOwner {
        require(forestRoot == bytes32(0), "FT: Already initialized");

        bytes32 taxiTreeRoot = getTaxiTreeRoot();
        bytes32 busTreeRoot = getBusTreeRoot();
        bytes32 ferryTreeRoot = getFerryTreeRoot();

        forestRoot = _initCacheForestRoot(
            taxiTreeRoot,
            busTreeRoot,
            ferryTreeRoot
        );

        _initializeBusTree(
            onboardingQueueCircuitId,
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );
    }

    /**
     * @notice Updates the reward parameters for the bus queue.
     * @param reservationRate The new rate for reservations in the bus queue.
     * @param premiumRate The new premium rate for bus queue rewards.
     * @param minEmptyQueueAge The new minimum age for an empty bus queue.
     * @dev This function can only be called by the owner.
     */
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

    /**
     * @notice Updates the bus tree onboarding circuit id
     * @param circuitId The new circuit id
     * @dev This function can only be called by the owner.
     */
    function updateBusTreeCircuitId(uint160 circuitId) external onlyOwner {
        _updateCircuitId(circuitId);
    }

    /**
     * @notice Adds UTXOs to the bus queue.
     * @param utxos An array of UTXOs to be added to the bus queue.
     * @param cachedForestRootIndex The index of the cached forest root to verify.
     * @param currentForestRoot The current forest root to validate against.
     * @param currentStaticRoot The static root to validate against.
     * @param reward The reward associated with adding these UTXOs.
     * @return firstUtxoQueueId The queue ID of the first UTXO added.
     * @return firstUtxoIndexInQueue The index of the first UTXO in the queue.
     * @dev This function can only be called by the Panther Pool and checks for non-zero UTXOs.
     */
    function addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint256 cachedForestRootIndex,
        bytes32 currentForestRoot,
        bytes32 currentStaticRoot,
        uint96 reward
    )
        external
        onlyPantherPool
        nonZeroUtxosLength(utxos)
        checkPantherTreesRoots(
            cachedForestRootIndex,
            currentForestRoot,
            currentStaticRoot
        )
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue)
    {
        // The pool cannot execute this method before this contract is initialized
        (firstUtxoQueueId, firstUtxoIndexInQueue) = _addUtxosToBusQueue(
            utxos,
            reward
        );
    }

    /**
     * @notice Adds UTXOs to the bus queue and the taxi tree.
     * @param utxos An array of UTXOs to be added.
     * @param numTaxiUtxos The number of UTXOs to be added to the taxi tree.
     * @param cachedForestRootIndex The index of the cached forest root to verify.
     * @param currentForestRoot The current forest root to validate against.
     * @param currentStaticRoot The static root to validate against.
     * @param reward The reward associated with adding these UTXOs.
     * @return firstUtxoQueueId The queue ID of the first UTXO added.
     * @return firstUtxoIndexInQueue The index of the first UTXO in the queue.
     * @dev This function can only be called by the Panther Pool and checks for non-zero UTXOs.
     */
    function addUtxosToBusQueueAndTaxiTree(
        bytes32[] memory utxos,
        uint8 numTaxiUtxos,
        uint256 cachedForestRootIndex,
        bytes32 currentForestRoot,
        bytes32 currentStaticRoot,
        uint96 reward
    )
        external
        onlyPantherPool
        nonZeroUtxosLength(utxos)
        checkPantherTreesRoots(
            cachedForestRootIndex,
            currentForestRoot,
            currentStaticRoot
        )
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

        forestRoot = _cacheNewForestRoot(
            taxiTreeNewRoot,
            TAXI_TREE_FOREST_LEAF_INDEX
        );
    }

    /**
     * @notice Onboards a queue to the bus tree.
     * @param miner The address of the miner.
     * @param queueId The ID of the queue to be onboarded.
     * @param inputs The inputs required for onboarding.
     * @param proof The zero-knowledge proof to validate the onboarding.
     */
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

        forestRoot = _cacheNewForestRoot(
            busTreeNewRoot,
            BUS_TREE_FOREST_LEAF_INDEX
        );
    }

    /**
     * @notice Claims the mining reward for a specified receiver.
     * @param receiver The address to receive the mining reward.
     */
    function claimMiningReward(address receiver) external {
        _claimMinerRewards(msg.sender, receiver);
    }

    /**
     * @notice Claims the mining reward with a signature.
     * @param receiver The address to receive the mining reward.
     * @param v The recovery id of the signature.
     * @param r The r part of the signature.
     * @param s The s part of the signature.
     * @dev This function recovers the miner's address from the signature and processes
     * the reward claim.
     */
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
