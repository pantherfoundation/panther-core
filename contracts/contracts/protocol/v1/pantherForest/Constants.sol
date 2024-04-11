// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

// `PantherForest` tree leafs indices (leafs store specific merkle trees roots)
uint256 constant TAXI_TREE_FOREST_LEAF_INDEX = 0;
uint256 constant BUS_TREE_FOREST_LEAF_INDEX = 1;
uint256 constant FERRY_TREE_FOREST_LEAF_INDEX = 2;
uint256 constant STATIC_TREE_FOREST_LEAF_INDEX = 3;

// `PantherStaticTree` leafs indices (leafs store specific merkle trees roots)
uint256 constant ZASSET_STATIC_LEAF_INDEX = 0;
uint256 constant ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX = 1;
uint256 constant ZNETWORK_STATIC_LEAF_INDEX = 2;
uint256 constant ZZONE_STATIC_LEAF_INDEX = 3;
uint256 constant PROVIDERS_KEYS_STATIC_LEAF_INDEX = 4;

// TODO: add new types and sub types
uint8 constant TT_ZACCOUNT_ACTIVATION = 0x01;
uint8 constant TT_PRP_CLAIM = 0x02;
uint8 constant TT_PRP_CONVERSION = 0x03;
uint8 constant TT_MAIN_TRANSACTION = 0x04;
