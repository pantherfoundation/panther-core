// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    reuseEnvAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy},
    } = hre;

    if (reuseEnvAddress(hre, 'ORC')) return;

    const zAccountsRegistryProxy = await getContractAddress(
        hre,
        'ZAccountsRegistry_Proxy',
        '',
    );

    const prpVoucherGrantorProxy = await getContractAddress(
        hre,
        'PrpVoucherGrantor_Proxy',
        '',
    );

    const pzkp = await getContractAddress(hre, 'PZkp_token', 'PZKP_TOKEN');

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    await deploy('OnboardingController', {
        from: deployer,
        args: [
            multisig,
            pzkp,
            zAccountsRegistryProxy,
            prpVoucherGrantorProxy,
            vaultProxy,
        ],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: multisig,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['onboarding-reward-ctrl', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'protocol-token',
    'z-accounts-registry-proxy',
    'prp-voucher-grantor',
    'vault-proxy',
];
