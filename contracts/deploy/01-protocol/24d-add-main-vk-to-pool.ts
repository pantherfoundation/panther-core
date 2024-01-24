// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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

    console.log('Adding main key to panther pool');
    const circuitId = getContractEnvAddress(hre, 'VK_MAIN');

    const tx = await pantherPool.updateMainCircuitId(circuitId);
    const res = await tx.wait();
    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['add-main-key-to-pool', 'protocol'];
func.dependencies = ['check-params', 'add-verification-key'];
