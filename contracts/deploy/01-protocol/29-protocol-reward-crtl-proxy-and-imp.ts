// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    getVestingPoolsContract,
    getZkpToken,
} from '../../lib/deploymentHelpers';
import {isLocal, isProd} from '../../lib/checkNetwork';

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
func.dependencies = ['check-params'];
