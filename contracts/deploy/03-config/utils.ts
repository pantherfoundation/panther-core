// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';

// Cross-chain bridge contract addresses
export const BRIDGE_ADDRESSES = {
    daoMultisig: '0x505796f5bc290269d2522cf19135ad7aa60dfd77',
    polygonMultisig: '0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0',
    fxChild: '0x8397259c983751daf40400790063935a11afa28a',
    fxRoot: '0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2',
    maticBridgeModule: '0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76',
};

// ABI definitions for cross-chain bridge contracts
export const fxRootAbi = [
    {
        inputs: [
            {internalType: 'address', name: '_receiver', type: 'address'},
            {internalType: 'bytes', name: '_data', type: 'bytes'},
        ],
        name: 'sendMessageToChild',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
];

export const maticBridgeModuleAbi = [
    {
        inputs: [
            {internalType: 'uint256', name: '', type: 'uint256'},
            {
                internalType: 'address',
                name: 'rootMessageSender',
                type: 'address',
            },
            {internalType: 'bytes', name: '_data', type: 'bytes'},
        ],
        name: 'processMessageFromRoot',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [],
        name: 'nonce',
        outputs: [{internalType: 'uint256', name: '', type: 'uint256'}],
        stateMutability: 'view',
        type: 'function',
    },
];

export interface SafeTransaction {
    to: string;
    data: string;
    operation: string;
    value: string;
}

export async function saveSafeTransaction(
    hre: HardhatRuntimeEnvironment,
    transaction: SafeTransaction,
    scriptFilename: string,
    suffix?: string,
): Promise<void> {
    const fs = await import('fs');
    const path = await import('path');

    const outputDir = path.join(
        __dirname,
        '../../deployments/safe-transactions',
    );
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, {recursive: true});
    }

    const scriptName = path.basename(scriptFilename, '.ts');
    const filename = suffix
        ? `${scriptName}-${suffix}-${hre.network.name}.json`
        : `${scriptName}-${hre.network.name}.json`;
    const outputFile = path.join(outputDir, filename);
    fs.writeFileSync(outputFile, JSON.stringify(transaction, null, 2));
}

export function createSafeTransaction(
    to: string,
    data: string,
    value: string = '0',
): SafeTransaction {
    return {
        to,
        data,
        operation: '0',
        value,
    };
}
