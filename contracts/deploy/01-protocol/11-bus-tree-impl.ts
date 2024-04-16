// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getContractEnvAddress,
    getNamedAccount,
    getPZkpToken,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, get},
    } = hre;

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    const pantherVerifier = await getContractAddress(
        hre,
        'PantherVerifier',
        'PANTHER_VERIFIER',
    );

    const pointer = getContractEnvAddress(hre, 'VK_PANTHERBUSTREEUPDATER');

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    const pZkp = await getPZkpToken(hre);

    if (pointer) {
        await deploy('PantherBusTree_Implementation', {
            contract: 'PantherBusTree',
            from: deployer,
            args: [
                multisig,
                pZkp.address,
                pantherPool,
                pantherVerifier,
                pointer,
            ],
            libraries: {
                PoseidonT3: poseidonT3,
            },
            log: true,
            autoMine: true,
        });
    } else console.log('Undefined pointer, skip BusTree deployment');
};
export default func;

func.tags = ['bus-tree-imp', 'forest', 'protocol'];
func.dependencies = [
    'crypto-libs',
    'deployment-consent',
    'pool-v1-proxy',
    'verifier',
    'add-verification-key',
    'pzkp-token',
];
