// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./pantherForest/interfaces/ITreeRootGetter.sol";

/**
 * @title ZAssetsRegistryV1
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

contract ZAssetsRegistryV1 is ITreeRootGetter {
    /** 
    Consists of a two leafs: testZKP on Mumbai, matic on Mumbai
    root: 0x23ab72c51302b4c48a739b16a00c52586fc1b3970af5d92f00fe14064258b861

    leaf 0: (public testnet) testZKP token on Mumbai
    leaf index: 0,
    commitment: 0x03d7278643304e1170f0fee590ef88dbb57c4bbc9ef4d7a8de0233fc96861fa8,
    = poseidon([
        // param: zAsset (i.e. zAssetId, but it's not the leaf index)
        // (zAssetId MUST be 0 for ZKP on all networks)
        0,
        // param: token (i.e. address of the token contract on this network)
        // (ZKP address on Mumbai)
        BigInt('0x4004C49aBb96B11D89A52DeCCa2D1522da7f3089'),
        // param: tokenId
        // (irrelevant for ERC-20 and the native token)
        0,
        // param: network
        // (mumbai)
        2,
        // param: offset
        // (irrelevant for ERC-20 and the native token)
        0,
        // param: weight
        // (1 ZKP = 1e6 scaled units * 20 = 2e7 weighted units)
        20,
        // param: scale
        // (1 ZKP = 1e18 unscaled units / 1e12 = 1e6 scaled units)
        1e12
    ])

    siblings: [
    '0x1ed4af569e93a7f50513c957cfe90b1c3d3157df8800aac9a0e58b13a40acef2',
    '0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4',
    '0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8',
    '0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c',
    '0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800',
    '0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f',
    '0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69',
    '0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f',
    '0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7',
    '0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718',
    '0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58',
    '0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f',
    '0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6',
    '0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d',
    '0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55',
    '0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c'
    ]

    leaf 1: (public testnet) testZKP token on Mumbai Matic (naive token) on Mumbai
    leaf index: 1,
    commitment: 0x1ed4af569e93a7f50513c957cfe90b1c3d3157df8800aac9a0e58b13a40acef2,
    = poseidon([
        // param: zAsset (i.e. zAssetId, but it's not the leaf index)
        // (IDs for the native tokens of different networks MUST be different)
        // (zAsset 1 reserved for ETH on the mainnet)
        2,
        // param: token (i.e. address of the token contract on this network)
        // (MUST be 0 for the native token on all networks)
        0,
        // param: tokenId
        // (irrelevant for ERC-20 and the native token)
        0,
        // param: network
        // (mumbai)
        2,
        // param: offset
        // (irrelevant for ERC-20 and the native token)
        0,
        // param: weight
        // (1 Matic = 1e6 scaled units * 700 = 7e8 weighted units)
        700,
        // param: scale
        // (1 Matic = 1e18 unscaled units / 1e12 = 1e6 scaled units)
        1e12
    ])

    siblings: [
    '0x03d7278643304e1170f0fee590ef88dbb57c4bbc9ef4d7a8de0233fc96861fa8',
    '0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4',
    '0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8',
    '0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c',
    '0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800',
    '0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f',
    '0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69',
    '0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f',
    '0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7',
    '0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718',
    '0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58',
    '0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f',
    '0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6',
    '0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d',
    '0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55',
    '0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c'
    ]
*/
    function getRoot() external pure returns (bytes32) {
        return
            0x23ab72c51302b4c48a739b16a00c52586fc1b3970af5d92f00fe14064258b861;
    }
}
