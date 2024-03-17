// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractAddress, getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    const zAccountRegistryProxy = await getContractAddress(
        hre,
        'zAccountsRegistry_Proxy',
        '',
    );

    await deploy('ZAccountsStatusResolver', {
        from: deployer,
        args: [zAccountRegistryProxy],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['z-accounts-resolver', 'forest', 'protocol'];
func.dependencies = ['deployment-consent', 'z-accounts-registry-proxy'];
