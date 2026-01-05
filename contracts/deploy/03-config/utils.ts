// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';

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
