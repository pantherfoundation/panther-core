// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getContractEnvAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    await deploy('PantherTaxiTree', {
        from: deployer,
        args: [pantherPool],
        libraries: {
            PoseidonT3: poseidonT3,
        },
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: deployer,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['taxi-tree', 'forest', 'protocol'];
func.dependencies = ['crypto-libs', 'deployment-consent'];
