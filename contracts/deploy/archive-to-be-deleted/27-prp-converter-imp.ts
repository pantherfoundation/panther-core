// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    getPZkpToken,
    reuseEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy},
    } = hre;
    await verifyUserConsentOnProd(hre, deployer);
    if (reuseEnvAddress(hre, 'ORC')) return;

    const pZkp = await getPZkpToken(hre);

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    await deploy('PrpConverter_Implementation', {
        contract: 'PrpConverter',
        from: deployer,
        args: [multisig, pZkp.address, pantherPool, vaultProxy],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['prp-converter-imp', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'protocol-token',
    'pool-v1-proxy',
    'vault-proxy',
];
