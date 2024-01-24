// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal} from '../../lib/checkNetwork';
import {getContractAddress, getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isLocal(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');
    const zkp = await getContractAddress(hre, 'PZkp_token', '');
    const pzkp = await getContractAddress(hre, 'PZkp_token', '');
    const {
        deployments: {deploy},
    } = hre;

    await deploy('MockFxPortal', {
        from: deployer,
        args: [deployer, zkp, pzkp],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: deployer,
        },
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['mock-fx-portal', 'dev-dependency'];
func.dependencies = ['protocol-token'];
