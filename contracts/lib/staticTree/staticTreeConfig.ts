// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';

export const NETWORK_TYPE = ['testnet', 'canary'] as const;
export type NetworkType = (typeof NETWORK_TYPE)[number];

const polygonNetworkId = 1;
const amoyNetworkId = 2;

export const tokenDetails = {
    testnet: {
        ZKP_TOKEN: {
            address: '0x9C56E89D8Aa0d4A1fB769DfbEa80D6C29e5A2893',
            weight: 110,
            scale: BigInt(1e14),
            decimals: 18,
            type: 'ERC20',
            networkId: amoyNetworkId,
        },
        NATIVE_TOKEN: {
            address: ethers.constants.AddressZero,
            weight: 5000,
            scale: BigInt(1e14),
            decimals: 18,
            type: 'Native',
            networkId: amoyNetworkId,
        },
        LINK_TOKEN: {
            address: '0xA82B5942DD61949Fd8A2993dCb5Ae6736F8F9E60',
            weight: 1400,
            scale: BigInt(1e12),
            decimals: 18,
            type: 'ERC20',
            networkId: amoyNetworkId,
        },
    },
    canary: {
        ZKP_TOKEN: {
            address: '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC',
            weight: 110,
            scale: BigInt(1e14),
            decimals: 18,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        NATIVE_TOKEN: {
            address: ethers.constants.AddressZero,
            weight: 4500,
            scale: BigInt(1e14),
            decimals: 18,
            type: 'Native',
            networkId: polygonNetworkId,
        },
        LINK_TOKEN: {
            address: '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39',
            weight: 1400,
            scale: BigInt(1e12),
            decimals: 18,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        UNI: {
            address: '0xb33EaAd8d922B1083446DC23f610c2567fB5180f',
            weight: 920,
            scale: BigInt(1e12),
            decimals: 18,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        AAVE: {
            address: '0xD6DF932A45C0f255f85145f286eA0b292B21C90B',
            weight: 1700,
            scale: BigInt(1e11),
            decimals: 18,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        GRT: {
            address: '0x5fe2B58c013d7601147DcdD68C143A77499f5531',
            weight: 2200,
            scale: BigInt(1e14),
            decimals: 18,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        QUICK: {
            address: '0xB5C064F955D8e7F38fE0460C556a72987494eE17',
            weight: 417,
            scale: BigInt(1e14),
            decimals: 6,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
    },
};
