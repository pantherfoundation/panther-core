// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

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
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['uniswap-router-plugin', 'core', 'protocol-v1'];
func.dependencies = ['vault-v1'];
