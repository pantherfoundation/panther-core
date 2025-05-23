// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    getContractAddress,
    verifyUserConsentOnProd,
} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);
    if (reuseEnvAddress(hre, 'VAULT_IMP')) return;

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV0_Proxy',
        'PANTHER_POOL_V0_PROXY',
    );

    await deploy('Vault_Implementation', {
        contract: 'VaultV0',
        from: deployer,
        args: [pantherPool],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['vault-v0-impl', 'protocol-v0'];
func.dependencies = ['check-params', 'pool'];
