// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getContractEnvAddress,
    getNamedAccount,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, get},
    } = hre;
    await verifyUserConsentOnProd(hre, deployer);

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    const staticTree = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );

    await deploy('ZAssetsRegistryV1', {
        from: deployer,
        args: [multisig, staticTree],
        libraries: {
            PoseidonT3: poseidonT3,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['z-assets-registry', 'forest', 'protocol'];
