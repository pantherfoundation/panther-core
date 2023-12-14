// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./pantherForest/interfaces/ITreeRootGetter.sol";

contract ZZonesRegistry is ITreeRootGetter {
    /** 
    The single leaf in the tree - for the single zone
    root: 0x05312bb654386ee048804204c37eeb644e540b296ed1a0fe933e8cdbfd99851c

    Leaf for the only zone
    leaf index: 0,
    commitment: 0x2644e2d33595d5b4c084fd39aa04e19a4756118103e1364dd81cb40b5a4cf34c,
    = poseidon([
        // param: `zoneId`
        // ID of the only zone currently active
        1n,

        // param: `edDsaPubKey[0]`
        // x-coordinate of the of the Zone Safe operator's pubkey
        13969057660566717294144404716327056489877917779406382026042873403164748884885n,

        // param: `edDsaPubKey[1]`
        // y-coordinate of the of the Zone Safe operator's pubkey
        11069452135192839850369824221357904553346382352990372044246668947825855305207n,

        // param: `originZoneIDs`
        // List of allowed origin zones IDs
        // (the only zone, with zoneId "1", is allowed yet)
        1n,

        // param: `targetZoneIDs`
        // List of allowed target zones IDs
        // (only this zone, with zoneId "1", is allowed yet)
        1n,

        // param: `zZoneNetworkIDsBitMap`
        // The bit map of allowed network (bit index is the networkId)
        // Two one-bit flags are set (to "1"):
        // - bit #0 (LS bit) - Goerli (zNetworkId = 0) enabled
        // - bit #1 - Mumbai (zNetworkId = 1) enabled
        3n,

        // param: `zZoneKycKytMerkleTreeLeafIDsAndRulesList`
        // List of allowed KYC/KYT pubkeys and rules (up to 10 elements x 24 bits each)
        // 2 elements defined:
        // - 1st element, in LS bits 0-23:
        //   - KYC rule ID, 91 ('0b01011011'), in 8 LS bits,
        //   - followed by the provider pubkey leaf index, 0, in next 16 bits
        // - 2nd element, in LS bits 24-47):
        //   - KYT rule ID, 94 ('0b01011110'), in 8 LS bits,
        //   - followed by the provider pubkey leaf index, 0, in next 16 bits
        // This two groups combine in 0b 000000000000000001011110 000000000000000001011011,
        1577058395n,

        // param: `zZoneKycExpiryTime`
        // Period in seconds of KYC attestation validity
        // (120 days)
        10368000n,

        // param: `zZoneKytExpiryTime`
        // Period in seconds of KYT attestation validity
        // (24 hours)
        86400n,

        // param: `zZoneDepositMaxAmount`
        // Maximum allowed deposit amount
        // (expressed in the "weighted units")
        BigInt(1e12), // equivalent to $1K at the targeted 1e-9 $/weighted_unit

        // param: `zZoneWithrawMaxAmount`
        // Maximum allowed withdrawal amount
        // (expressed in the "weighted units")
        BigInt(1e12),

        // param: `zZoneInternalMaxAmount`
        // Maximum allowed internal tx amount
        // (expressed in the "weighted units")
        BigInt(1e12),

        // param: `zZoneZAccountIDsBlackList`
        // Zone-level List of blacklisted zAccount IDs (10 elements of 24 bits each)
        // The zAccount ID of 0x0FFF can't exist. 24 bits set to "1" in a list
        // element means "no zAccount" is blacklisted. 240 bits set to one means
        // "no zAccounts are blacklisted")
        // The value is  240 bits set to 1:
        1766847064778384329583297500742918515827483896875618958121606201292619775n,

        // param: `zZoneMaximumAmountPerTimePeriod`
        // Limit on the sum of deposits+withdrawals+internal_txs amounts
        // for the period defined further
        // (expressed in the "weighted units")
        BigInt(1e13), // equivalent to $10K at the targeted 1e-9 $/weighted_unit

        // param: `zZoneTimePeriodPerMaximumAmount`
        // Period to count the above limit for
        // (24 hours)
        86400n
  ])

    siblings: [
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d',
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
            0x05312bb654386ee048804204c37eeb644e540b296ed1a0fe933e8cdbfd99851c;
    }
}
