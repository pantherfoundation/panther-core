// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

/// @dev Leaf zero value (`keccak256("Pantherprotocol")%FIELD_SIZE`)
bytes32 constant ZERO_VALUE = bytes32(
    uint256(0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d)
);

// The roots of empty trees follow.
// An "empty" tree is a binary merkle tree of a given number of levels bellow
// the root (depth), fully populated with ZERO_VALUE leafs, with the `poseidon`
// hash function applied.
// (computed by `../../../../lib/binaryMerkleZerosContractGenerator.ts`)

uint256 constant TWO_LEVELS = 2;
/// @dev Root of the binary merkle TWO_LEVELS tree with ZERO_VALUE leafs
// Level 0: ZERO_VALUE
// Level 1: 0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4
bytes32 constant TWO_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8)
);

uint256 constant SIX_LEVELS = 6;
/// @dev Root of the binary merkle SIX_LEVELS tree with ZERO_VALUE leafs
// Level 0: ZERO_VALUE
// Level 1: 0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4
// Level 2: 0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8
// Level 3: 0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c
// Level 4: 0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800
// Level 5: 0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f
bytes32 constant SIX_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69)
);

uint256 constant EIGHT_LEVELS = 8;
/// @dev Root of the binary merkle EIGHT_LEVELS tree with ZERO_VALUE leafs
// Level 6: SIX_LEVEL_EMPTY_TREE_ROOT
// Level 7: 0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f
bytes32 constant EIGHT_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7)
);

uint256 constant SIXTEEN_LEVELS = 16;
/// @dev Root of the binary merkle SIXTEEN_LEVELS tree with ZERO_VALUE leafs
// Level 8:  EIGHT_LEVEL_EMPTY_TREE_ROOT
// Level 9:  0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718
// Level 10: 0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58
// Level 11: 0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f
// Level 12: 0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6
// Level 13: 0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d
// Level 14: 0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55
// Level 15: 0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c
bytes32 constant SIXTEEN_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x0a5e5ec37bd8f9a21a1c2192e7c37d86bf975d947c2b38598b00babe567191c9)
);

uint256 constant TWENTY_LEVELS = 20;
/// @dev Root of the merkle binary TWENTY_LEVELS tree with ZERO_VALUE leafs
// Level 16: SIXTEEN_LEVEL_EMPTY_TREE_ROOT
// Level 17: 0x21fb04b171b68944c640020a3a464602ec8d02495c44f1e403d9be4a97128e49
// Level 18: 0x19151c748859974805eb30feac7a301266dec9f67e23e285fe750f86448a2af9
// Level 19: 0x18fb0b755218eaa809681eb87e45925faa9197507d368210d73b5836ebf139e4
bytes32 constant TWENTY_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x1e294375b42dfd97795e07e1fe8bd6cefcb16c3bbb71b30bed950f8965861244)
);

uint256 constant TWENTY_SIX_LEVELS = 26;
/// @dev Root of the binary merkle TWENTY_SIX_LEVELS tree with ZERO_VALUE leafs
// Level 21: 0x0d3e4235db275d9bab0808dd9ade8789d46d0e1f1c9a99ce73fefca51dc92f4a
// Level 22: 0x075ab2ca945c4dc5ea40a9f1c66d5bf3c367cef1e04e73aa17c2bc747eb5fc87
// Level 23: 0x26f0f533a8ea2210001aeb8f8306c7c70656ba6afe145c6540bd4ed2c967a230
// Level 24: 0x24be7e64f680326e6e3621e5862d7b6b1f31e9e183a0bf5dd04e823be84e6af9
// Level 25: 0x212b13c9cbf421942ae3e3c62a3c072903c2a745a220cfb3c43cd520f55f44bf
bytes32 constant TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x1bdded415724018275c7fcc2f564f64db01b5bbeb06d65700564b05c3c59c9e6)
);

uint256 constant THIRTY_TWO_LEVELS = 32;
/// @dev Root of the binary merkle THIRTY_TWO_LEVELS tree with ZERO_VALUE leafs
// Level 26: TWENTY_SIX_LEVEL_EMPTY_TREE_ROOT
// Level 27: 0x038acf368a174e10c45a64161131c0f93faf2f045ff663acbef804eb5644aad7
// Level 28: 0x1b3ecbe4131d8d52d60b91ec8e13d5fc82235232bb43007d54cda6b50d932d6f
// Level 29: 0x1b0b9059f431d38a66c82317d9ed1b744c439f10193ae44bcf519fe6e1766b65
// Level 30: 0x240867e8bb31d6b8057f5ab067dc0bd1c4ba64a42258963ec45b7b4773ce5838
// Level 31: 0x2310e5b3543ea766ecaec53003d0e1b73f19a149409190d00561da7090a2c5cb
bytes32 constant THIRTY_TWO_LEVEL_EMPTY_TREE_ROOT = bytes32(
    uint256(0x24ab16594d418ca2e66ca284f56a4cb7039c6d8f8e0c3c8f362cf18b5afa19d0)
);
