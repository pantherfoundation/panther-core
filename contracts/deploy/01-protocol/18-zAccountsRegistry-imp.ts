// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getContractAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, get},
    } = hre;

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    const staticTree = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );
    const onboardingController = await getContractAddress(
        hre,
        'OnboardingController',
        '',
    );

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    await deploy('ZAccountsRegistry_Implementation', {
        contract: 'ZAccountsRegistry',
        from: deployer,
        args: [multisig, 1, pantherPool, staticTree, onboardingController],
        libraries: {PoseidonT3: poseidonT3},
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['z-accounts-registry-imp', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'pool-v1-proxy',
    'protocol-token',
    'static-tree-proxy',
    'onboarding-reward-ctrl',
];
