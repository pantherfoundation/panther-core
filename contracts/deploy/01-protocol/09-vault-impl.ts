// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    getContractAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    if (reuseEnvAddress(hre, 'VAULT_IMP')) return;

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    await deploy('Vault_Implementation', {
        contract: 'VaultV1',
        from: deployer,
        args: [pantherPool],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['vault-impl', 'protocol'];
func.dependencies = ['check-params', 'deployment-consent', 'pool-v1-proxy'];
