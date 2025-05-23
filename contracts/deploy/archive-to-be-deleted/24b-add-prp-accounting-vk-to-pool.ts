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

    console.log('Adding prp accounting key to panther pool');
    const circuitId = getContractEnvAddress(hre, 'VK_PRPACCOUNTING');

    const tx = await pantherPool.updateCircuitId(0x103, circuitId);
    const res = await tx.wait();
    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['add-prp-accounting-key-to-pool', 'protocol'];
func.dependencies = [
    'check-params',
    'pool-v1-proxy',
    'prp-accounting-vk',
    'add-verification-key',
];
