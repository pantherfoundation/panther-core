// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {reuseEnvAddress, getNamedAccount} from '../../lib/deploymentHelpers';
import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
    getPoseidonT5Contract,
    getPoseidonT6Contract,
} from '../../lib/poseidonBuilder';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    if (!reuseEnvAddress(hre, 'POSEIDON_T3')) {
        const PoseidonT3 = await getPoseidonT3Contract();
        await deploy('PoseidonT3', {
            contract: {
                abi: PoseidonT3.interface.format('json'),
                bytecode: PoseidonT3.bytecode,
            },
            from: deployer,
            args: [],
            libraries: {},
            log: true,
            autoMine: true,
        });
    }

    if (!reuseEnvAddress(hre, 'POSEIDON_T4')) {
        const PoseidonT4 = await getPoseidonT4Contract();
        await deploy('PoseidonT4', {
            contract: {
                abi: PoseidonT4.interface.format('json'),
                bytecode: PoseidonT4.bytecode,
            },
            from: deployer,
            args: [],
            libraries: {},
            log: true,
            autoMine: true,
        });
    }

    if (!reuseEnvAddress(hre, 'POSEIDON_T5')) {
        const PoseidonT5 = await getPoseidonT5Contract();
        await deploy('PoseidonT5', {
            contract: {
                abi: PoseidonT5.interface.format('json'),
                bytecode: PoseidonT5.bytecode,
            },
            from: deployer,
            args: [],
            libraries: {},
            log: true,
            autoMine: true,
        });
    }

    if (!reuseEnvAddress(hre, 'POSEIDON_T6')) {
        const PoseidonT6 = await getPoseidonT6Contract();
        await deploy('PoseidonT6', {
            contract: {
                abi: PoseidonT6.interface.format('json'),
                bytecode: PoseidonT6.bytecode,
            },
            from: deployer,
            args: [],
            libraries: {},
            log: true,
            autoMine: true,
        });
    }
};
export default func;

func.tags = ['crypto-libs', 'protocol'];
func.dependencies = ['check-params', 'deployment-consent'];
