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
     * ZAssets tree root generation
     * This tree consists of a single leaf yet: testZKP on Mumbai
     *      - leafIndex = 0
     *      - commitment = poseidon([
     *              0, // zAsset (zAssetId MUST be 0 for ZKP on all networks)
     *              BigInt('0x4004C49aBb96B11D89A52DeCCa2D1522da7f3089'), // token (ZKP address on Mumbai)
     *              0, // tokenId (irrelevant)
     *              2, // network (mumbai)
     *              0, // offset
     *              1, // weight
     *              12, // scale (UTXO amount = external amounts * 1e-12)
  
     *
     *          ]) = 0x04c47be1c966148d8373a2c9a8725fa5a648678416cbe5a39c1600b69e31666a
     *               // (2156408421028048248978532747114059242009883911295094375617969196164719928938n)
     *
     *      - siblings = [
     *              0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d,
     *              0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4,
     *              0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8,
     *              0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c,
     *              0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800,
     *              0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f,
     *              0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69,
     *              0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f,
     *              0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7,
     *              0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718,
     *              0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58,
     *              0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f,
     *              0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6,
     *              0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d,
     *              0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55,
     *              0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c
     *          ]
     */
    function getRoot() external pure returns (bytes32) {
        // 3723247354377620069387735695862260139005999863996254561023715046060291769010n
        return
            0x083b4887dfb6b09c333fdaea1a3ff792183758862ebb371b60de839b7a57c2b2;
    }
}
