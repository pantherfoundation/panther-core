// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
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

    await deploy('MockTaxiTree', {
        from: deployer,
        libraries: {
            PoseidonT3: poseidonT3,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['taxi-tree', 'forest', 'protocol'];
func.dependencies = ['crypto-libs', 'deployment-consent'];
