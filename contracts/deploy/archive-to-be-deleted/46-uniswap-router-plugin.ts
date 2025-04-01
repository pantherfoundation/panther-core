// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractAddress, getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const swapRouter = await getNamedAccount(hre, 'swapRouter');
    const quoterV2 = await getNamedAccount(hre, 'quoterV2');

    const {
        deployments: {deploy},
    } = hre;

    const vaultProxyAddress = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    await deploy('UniswapV3RouterPlugin', {
        from: deployer,
        args: [swapRouter, quoterV2, vaultProxyAddress],
        proxy: {
            proxyContract: 'EIP173ProxyWithReceive',
            owner: multisig,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['uni-router-plugin'];
func.dependencies = ['check-params', 'deployment-consent'];
