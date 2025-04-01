// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {
    getNamedAccount,
    getVestingPoolsContract,
    getZkpToken,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy},
    } = hre;

    const zkp = await getZkpToken(hre);

    const vPool = await getVestingPoolsContract(hre);

    await deploy('ProtocolRewardController', {
        from: deployer,
        args: [multisig, zkp.address, vPool.address],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: multisig,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['protocol-reward-ctrl', 'protocol'];
func.dependencies = ['check-params', 'deployment-consent', 'protocol-token'];
