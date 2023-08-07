// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

// TODO: rename pantherForest/Constant.sol to pantherForest/Constants.sol

// `PantherForest` tree leafs indices (leafs store specific merkle trees roots)
uint256 constant TAXI_TREE_FOREST_LEAF_INDEX = 0;
// TODO: use ("import") BUS_TREE_FOREST_LEAF_INDEX in BusTree.sol;
uint256 constant BUS_TREE_FOREST_LEAF_INDEX = 1;
uint256 constant FERRY_TREE_FOREST_LEAF_INDEX = 2;
uint256 constant STATIC_TREE_FOREST_LEAF_INDEX = 3;

// `PantherStaticTree` leafs indices (leafs store specific merkle trees roots)
uint256 constant ZASSET_STATIC_LEAF_INDEX = 0;
// TODO: update ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX: must be 1
uint256 constant ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX = 3;
uint256 constant ZNETWORK_STATIC_LEAF_INDEX = 2;
uint256 constant ZZONE_STATIC_LEAF_INDEX = 3;
// TODO: update PROVIDERS_KEYS_STATIC_LEAF_INDEX: must be 4
uint256 constant PROVIDERS_KEYS_STATIC_LEAF_INDEX = 2;
