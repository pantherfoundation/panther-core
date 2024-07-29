// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./interfaces/IPantherTrees.sol";
import "./pantherTrees/interfaces/IPantherTreesRootGetter.sol";

import "./pantherTrees/PantherForest.sol";
import "./pantherTrees/PantherStaticTree.sol";
import "./pantherTrees/PantherTaxiTree.sol";
import "./pantherTrees/PantherBusTree.sol";
import "./pantherTrees/PantherFerryTree.sol";
import "../../common/ImmutableOwnable.sol";

import "./pantherTrees/Constants.sol";
import "./errMsgs/PantherTreesErrMsgs.sol";

contract PantherTrees is
    PantherForest,
    PantherStaticTree,
    PantherTaxiTree,
    PantherBusTree,
    PantherFerryTree,
    ImmutableOwnable,
    IPantherTrees,
    IPantherTreesRootGetter
{
    bytes32[50] private _gap;

    event Initialized(bytes32 pantherForestRoot, bytes32 pantherStaticRoot);

    modifier onlyPantherPool() {
        require(msg.sender == PANTHER_POOL, ERR_UNAUTHORIZED);
        _;
    }
    modifier nonZeroUtxosLength(bytes32[] memory utxos) {
        require(utxos.length != 0, ERR_EMPTY_UTXOS_ARRAY);
        _;
    }

    constructor(
        address _owner,
        address _pantherPool,
        address _pantherVerifier,
        address _feeMaster,
        address _zkpToken,
        uint8 _miningRewardVersion,
        PantherStaticTrees memory pantherStaticTrees
    )
        PantherStaticTree(pantherStaticTrees)
        PantherBusTree(
            _pantherPool,
            _pantherVerifier,
            _feeMaster,
            _zkpToken,
            _miningRewardVersion
        )
        ImmutableOwnable(_owner)
    {}

    function getRoots()
        external
        view
        returns (bytes32 _pantherStaticRoot, bytes32 _pantherForestRoot)
    {
        _pantherStaticRoot = pantherStaticRoot;
        _pantherForestRoot = pantherForestRoot;
    }

    function verifyPantherTreesRoots(
        uint256 _cachedForestRootIndex,
        bytes32 _pantherForestRoot,
        bytes32 _pantherStaticRoot
    ) external view returns (bool) {
        return
            isCachedRoot(_pantherForestRoot, _cachedForestRootIndex) &&
            _pantherStaticRoot == pantherStaticRoot;
    }

    function initialize(
        uint160 onboardingQueueCircuitId,
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) external onlyOwner {
        require(onboardingQueueCircuitId == 0, ERR_PT_INIT);

        bytes32 taxiTreeRoot = getTaxiTreeRoot();
        bytes32 busTreeRoot = getBusTreeRoot();
        bytes32 ferryTreeRoot = getFerryTreeRoot();

        bytes32 _pantherForestRoot = _initializeForest(
            taxiTreeRoot,
            busTreeRoot,
            ferryTreeRoot
        );
        bytes32 _pantherStaticRoot = _initializeStaticTree();

        _initializeBusTree(
            onboardingQueueCircuitId,
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );

        emit Initialized(_pantherForestRoot, _pantherStaticRoot);
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

    function updateStaticRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        // checking if contract is initialized
        require(onboardingQueueCircuitId != 0, ERR_PT_NOT_INIT);

        // can only be executed by `PantherStaticTrees` contracts
        _updateStaticRoot(updatedLeaf, leafIndex);
    }

    function addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 reward
    )
        external
        onlyPantherPool
        nonZeroUtxosLength(utxos)
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
        uint96 reward,
        uint8 numTaxiUtxos
    )
        external
        onlyPantherPool
        nonZeroUtxosLength(utxos)
        returns (uint32 firstUtxoQueueId, uint8 firstUtxoIndexInQueue)
    {
        // The pool cannot execute this method before this contract is initialized

        require(numTaxiUtxos <= 3, ERR_INVALID_TAXI_UTXOS_COUNT);

        (firstUtxoQueueId, firstUtxoIndexInQueue) = _addUtxosToBusQueue(
            utxos,
            reward
        );

        bytes32 taxiTreeNewRoot;

        if (numTaxiUtxos == 1) {
            taxiTreeNewRoot = _addUtxoToTaxiTree(utxos[0]);
        }
        if (numTaxiUtxos == 2) {
            taxiTreeNewRoot = _addThreeUtxosToTaxiTree(
                utxos[0],
                utxos[1],
                bytes32(0)
            );
        }
        if (numTaxiUtxos == 3) {
            taxiTreeNewRoot = _addThreeUtxosToTaxiTree(
                utxos[0],
                utxos[1],
                utxos[2]
            );
        }

        _updateForestRoot(taxiTreeNewRoot, TAXI_TREE_FOREST_LEAF_INDEX);
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

        _updateForestRoot(busTreeNewRoot, BUS_TREE_FOREST_LEAF_INDEX);
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
