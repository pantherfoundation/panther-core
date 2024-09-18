// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getContractEnvAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const pantherPoolAddress = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    const {abi} = await artifacts.readArtifact('PantherPoolV1');
    const pantherPool = await ethers.getContractAt(abi, pantherPoolAddress);

    console.log('Adding zAccount registration key to panther pool');
    const circuitId = getContractEnvAddress(hre, 'VK_ZACCOUNTSREGISTRATION');

    const tx = await pantherPool.updateCircuitId(0x100, circuitId);
    const res = await tx.wait();
    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['add-zaccount-registration-key-to-pool', 'protocol'];
func.dependencies = [
    'check-params',
    'pool-v1-proxy',
    'zaccount-vk',
    'add-verification-key',
];
