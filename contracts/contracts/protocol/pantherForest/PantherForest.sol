// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./interfaces/ITreeRootGetter.sol";
import "./interfaces/ITreeRootUpdater.sol";
import "./rootHistory/RootHistory.sol";
import "../../common/ImmutableOwnable.sol";
import { PoseidonT5 } from "../crypto/Poseidon.sol";
import "./Constants.sol";

/**
 * @title PantherForest
 * @notice It stores and updates leafs and the root of the Panther Forest Tree.
 * @dev "Panther Forest Tree" is a merkle tree with a single level (leafs) under
 * the root. It has 4 leafs, which are roots of 4 other merkle trees -
 * the "Taxi Tree", the "Bus Tree", the "Ferry Tree" and the "Static Tree"
 * (essentially, these 4 trees are subtree of the Panther Forest tree):
 *
 *          Forest Root
 *               |
 *     +------+--+---+------+
 *     |      |      |      |
 *     0      1      2      3
 *   Taxi   Bus    Ferry  Static
 *   Tree   Tree   Tree   Tree
 *   root   root   root   root
 *
 * Every of 4 trees are controlled by "tree" smart contracts. A "tree" contract
 * must call this contract to update the value of the leaf and the root of the
 * Forest Tree every time the "controlled" tree is updated.
 */
abstract contract PantherForest is
    RootHistory,
    ImmutableOwnable,
    ITreeRootGetter,
    ITreeRootUpdater
{
    bytes32[20] private _gap;

    // solhint-disable var-name-mixedcase

    uint256 private constant NUM_LEAFS = 4;
    uint256 private constant STATIC_TREE_LEAF = 3;
    uint256 private constant HISTORY_SIZE = 256;

    address public immutable TAXI_TREE_CONTROLLER;
    address public immutable BUS_TREE_CONTROLLER;
    address public immutable FERRY_TREE_CONTROLLER;
    address public immutable STATIC_TREE_CONTROLLER;

    // solhint-enable var-name-mixedcase

    bytes32 private _forestRoot;

    bytes32[NUM_LEAFS] public leafs;
    bytes32[HISTORY_SIZE] public rootHistory;
    uint64 private _savedRootsCounter;
    uint64 private _historyStartPos;
    uint8 internal _historyDepth;

    // mapping from leaf index to leaf controller
    mapping(uint8 => address) public leafControllers;

    constructor(
        address _owner,
        address _taxiTreeController,
        address _busTreeController,
        address _ferryTreeController,
        address _staticTreeController
    ) ImmutableOwnable(_owner) {
        require(
            _taxiTreeController != address(0) &&
                _busTreeController != address(0) &&
                _ferryTreeController != address(0) &&
                _staticTreeController != address(0),
            "init: zero address"
        );

        TAXI_TREE_CONTROLLER = _taxiTreeController;
        BUS_TREE_CONTROLLER = _busTreeController;
        FERRY_TREE_CONTROLLER = _ferryTreeController;
        STATIC_TREE_CONTROLLER = _staticTreeController;
    }

    function initialize() external onlyOwner {
        require(_forestRoot == bytes32(0), "PF: Already initialized");

        for (uint8 i; i < NUM_LEAFS; ) {
            leafs[i] = ITreeRootGetter(_getLeafController(i)).getRoot();
            unchecked {
                ++i;
            }
        }

        _forestRoot = hash(leafs);
    }

    function getRoot() external view returns (bytes32) {
        return _forestRoot;
    }

    function updateRoot(bytes32 updatedLeaf, uint256 leafIndex) external {
        require(msg.sender == _getLeafController(leafIndex), "unauthorized");

        leafs[leafIndex] = updatedLeaf;
        _forestRoot = hash(leafs);
        uint64 _rootHistoryIndex;
        if (leafIndex == STATIC_TREE_LEAF) {
            _rootHistoryIndex = _resetRootHistory(_forestRoot);
        } else {
            _rootHistoryIndex = _updateRootHistory(_forestRoot);
        }

        emit RootUpdated(uint8(leafIndex), updatedLeaf, _forestRoot);
    }

    function _getLeafController(uint256 leafIndex)
        internal
        view
        returns (address leafController)
    {
        require(leafIndex < NUM_LEAFS, "PF: INVALID_LEAF_IND");
        if (leafIndex == TAXI_TREE_FOREST_LEAF_INDEX)
            leafController = TAXI_TREE_CONTROLLER;

        if (leafIndex == BUS_TREE_FOREST_LEAF_INDEX)
            leafController = BUS_TREE_CONTROLLER;

        if (leafIndex == FERRY_TREE_FOREST_LEAF_INDEX)
            leafController = FERRY_TREE_CONTROLLER;

        if (leafIndex == STATIC_TREE_FOREST_LEAF_INDEX)
            leafController = STATIC_TREE_CONTROLLER;
    }

    function _updateRootHistory(bytes32 forestRoot)
        private
        returns (uint64 _rootHistoryIndex)
    {
        uint64 savedRootsCounter = _savedRootsCounter;

        if (_historyDepth < HISTORY_SIZE) _historyDepth++;

        // `& 0xFF` is a cheaper equivalent of `% 256`
        _rootHistoryIndex = (savedRootsCounter - _historyStartPos) & 0xFF;
        rootHistory[_rootHistoryIndex] = forestRoot;

        _savedRootsCounter = savedRootsCounter++;
    }

    function _resetRootHistory(bytes32 forestRoot)
        private
        returns (uint64 _rootHistoryIndex)
    {
        _historyStartPos = _savedRootsCounter;
        _historyDepth = 0;
        _rootHistoryIndex = 0;
        rootHistory[_rootHistoryIndex] = forestRoot;
    }

    function hash(bytes32[NUM_LEAFS] memory _leafs)
        internal
        pure
        returns (bytes32)
    {
        return PoseidonT5.poseidon(_leafs);
    }
}
