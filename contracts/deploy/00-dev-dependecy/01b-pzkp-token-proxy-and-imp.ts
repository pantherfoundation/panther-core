// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('MockPZkp', {
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: multisig,
        },
        from: deployer,
        args: [multisig],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['pzkp-token', 'dev-dependency'];
