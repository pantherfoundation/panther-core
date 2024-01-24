// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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
        'zAccountRegistry',
    );
};

export default func;

func.tags = ['z-accounts-registry-upgrade', 'protocol'];
