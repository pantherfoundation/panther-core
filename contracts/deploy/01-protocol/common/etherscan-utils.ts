// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import '@nomiclabs/hardhat-ethers';
import * as dotenv from 'dotenv';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

dotenv.config();

export function logtTenderly(hash) {
    console.log(`https://dashboard.tenderly.co/tx/polygon-amoy/${hash}`);
    console.log(`https://amoy.polygonscan.com/tx/${hash}`);
}

export async function attemptVerify(
    hre: HardhatRuntimeEnvironment,
    name: string,
    address: string,
): Promise<void> {
    const deployment = await hre.deployments.get(name);
    const args = deployment.args;

    try {
        await hre.run('verify:verify', {
            address: address,
            constructorArguments: args,
        });
    } catch (error) {
        console.error('Error during run verification:', error);
    }
}
