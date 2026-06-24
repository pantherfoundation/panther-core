// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;

    const poseidonT6 = (await get('PoseidonT6')).address;

    await deploy('StaticTree', {
        from: deployer,
        args: [treesDiamond],
        libraries: {PoseidonT6: poseidonT6},
        log: true,
        autoMine: true,
        gasPrice: await getGasPrice(hre),
    });
};
export default func;

func.tags = [
    'static-tree',
    'trees',
    'trees-facet',
    'protocol-v1',
    'protocol-v1-deploy',
];
func.dependencies = ['poseidon-libs-v1', 'trees-diamond'];
