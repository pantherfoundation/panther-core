// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
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
func.dependencies = ['check-params'];
