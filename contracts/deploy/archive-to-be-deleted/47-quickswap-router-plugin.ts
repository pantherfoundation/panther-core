// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractAddress, getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const quickswapRouter02 = await getNamedAccount(hre, 'quickswapRouter02');
    const quickswapFactory = await getNamedAccount(hre, 'quickswapFactory');
    const weth9 = await getNamedAccount(hre, 'weth9');

    const {
        deployments: {deploy},
    } = hre;

    const vaultProxyAddress = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    await deploy('QuickswapRouterPlugin', {
        from: deployer,
        args: [quickswapRouter02, quickswapFactory, vaultProxyAddress, weth9],
        proxy: {
            proxyContract: 'EIP173ProxyWithReceive',
            owner: multisig,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['quick-swap-router-plugin'];
func.dependencies = ['check-params', 'deployment-consent'];
