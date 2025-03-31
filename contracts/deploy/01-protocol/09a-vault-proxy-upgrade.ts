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

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );
    const vaultImpl = await getContractAddress(
        hre,
        'Vault_Implementation',
        'VAULT_IMP',
    );

    await upgradeEIP1967Proxy(hre, deployer, vaultProxy, vaultImpl, 'vault');
};

export default func;

func.tags = ['vault-upgrade', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'vault-proxy',
    'vault-impl',
];
