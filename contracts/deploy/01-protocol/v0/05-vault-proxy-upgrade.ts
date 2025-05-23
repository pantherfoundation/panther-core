// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

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

func.tags = ['vault-v0-upgrade', 'protocol-v0'];
func.dependencies = ['check-params', 'vault-v0-impl'];
