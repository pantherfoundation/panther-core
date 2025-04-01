// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const zAccountRegistryProxy = await getContractAddress(
        hre,
        'ZAccountsRegistry_Proxy',
        '',
    );
    const zAccountRegistryImpl = await getContractAddress(
        hre,
        'ZAccountsRegistry_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        zAccountRegistryProxy,
        zAccountRegistryImpl,
        'ZAccountRegistry',
    );
};

export default func;

func.tags = ['z-accounts-registry-upgrade', 'protocol'];
func.dependencies = [
    'deployment-consent',
    'z-accounts-registry-proxy',
    'z-accounts-registry-imp',
];
