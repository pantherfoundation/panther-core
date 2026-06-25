// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const uniswapRouter = await getNamedAccount(hre, 'uniswapRouter');
    const uniswapQuoterV2 = await getNamedAccount(hre, 'uniswapQuoterV2');

    const {
        deployments: {deploy, get},
    } = hre;

    const vaultV1 = (await get('VaultV1')).address;

    await deploy('UniswapV3RouterPlugin', {
        from: deployer,
        args: [uniswapRouter, uniswapQuoterV2, vaultV1],
        log: true,
        autoMine: true,
        gasPrice: await getGasPrice(hre),
    });
};
export default func;

func.tags = [
    'uniswap-router-plugin',
    'core',
    'protocol-v1',
    'protocol-v1-deploy',
];
func.dependencies = ['vault-v1'];
