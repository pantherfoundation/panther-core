// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    verifyUserConsentOnProd,
    getContractAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy, get},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);

    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

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

    const babyJubJub = await getContractAddress(hre, 'BabyJubJub', '');
    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    const constructorArgs = [
        multisig,
        1,
        pantherPool,
        staticTree,
        onboardingController,
    ];

    await deploy('ZAccountsRegistry_Implementation', {
        contract: 'ZAccountsRegistry',
        from: deployer,
        args: constructorArgs,
        libraries: {
            PoseidonT3: poseidonT3,
            BabyJubJub: babyJubJub,
        },
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['z-accounts-registry-imp', 'protocol'];
func.dependencies = ['check-params'];
