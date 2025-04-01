// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const quickswapRouter02 = await getNamedAccount(hre, 'quickswapRouter02');
    const quickswapFactory = await getNamedAccount(hre, 'quickswapFactory');
    const weth9 = await getNamedAccount(hre, 'weth9');

    const {
        deployments: {deploy, get},
    } = hre;

    const vaultV1 = (await get('VaultV1')).address;

    await deploy('QuickswapRouterPlugin', {
        from: deployer,
        args: [quickswapRouter02, quickswapFactory, vaultV1, weth9],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['quickswap-router-plugin', 'core', 'protocol-v1'];
func.dependencies = ['vault-v1'];
