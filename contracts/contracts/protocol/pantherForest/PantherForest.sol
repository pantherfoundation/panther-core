// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./rootHistory/RootHistory.sol";
import "../PantherStaticTree.sol";
import "../../common/ImmutableOwnable.sol";

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
abstract contract PantherForest is RootHistory, PantherStaticTree, ImmutableOwnable {

    enum LEAF_INDEX {
        TAXI_TREE,
        BUS_TREE,
        FERRY_TREE,
        STATIC_TREE
    }

    address immutable public TAXI_TREE;
    address immutable public BUS_TREE;
    address immutable public FERRY_TREE;
    address immutable public STATIC_TREE;



    bytes32 public forestRoot;
    bytes32[4] public treeRoots;
    // mapping from leaf index to leaf owner
    mapping(uint8 => address) public leafOwner;

    event ForestUpdated(uint8 indexed leafIndex, bytes32 updatedLeaf, bytes32 updatedRoot);


    constructor(address _taxiTree, address _busTree, address _ferryTree){
        require(_taxiTree != address(0) && _busTree != address(0) && _ferryTree!= address(0), 'init: zero address');

        TAXI_TREE = _taxiTree;
        BUS_TREE = _busTree;
        FERRY_TREE = _ferryTree;
    }


    function initialize(bytes32[4] memory _treeRoots) external onlyOwner {
        require(forestRoot == 0, 'Already initialized');

        for(uint8 i; i <_treeRoots.length;){
            treeRoots[i] = _treeRoots[i];
            unchecked {
                ++i;
            }
        }
        forestRoot = hash(_treeRoots);
    }

    function updateForest(bytes32 curRoot, bytes32 updatedLeaf, LEAF_INDEX leafIndex) external {
        require(msg.sender == leafOwner[uint8(leafIndex)],'unauthorized');


        bytes32[4] memory _treeRoots = treeRoots;
        _treeRoots[uint8(leafIndex)] = updatedLeaf;
        forestRoot = hash(_treeRoots);

        emit ForestUpdated(uint8(leafIndex), updatedLeaf, forestRoot);

    }

    function hash(bytes32[2] memory)
        internal
        pure
        virtual
        override
        returns (bytes32);

    function hash(bytes32[4] memory) internal pure virtual returns (bytes32);
}
