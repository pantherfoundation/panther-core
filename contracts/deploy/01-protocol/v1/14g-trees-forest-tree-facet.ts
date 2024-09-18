// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;
    const feeMaster = (await get('FeeMaster')).address;
    const miningRewardVersion = 1;

    const poseidonT3 = (await get('PoseidonT3')).address;
    const poseidonT4 = (await get('PoseidonT4')).address;

    await deploy('ForestTree', {
        from: deployer,
        args: [coreDiamond, feeMaster, pzkp, miningRewardVersion],
        libraries: {PoseidonT3: poseidonT3, PoseidonT4: poseidonT4},
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['forest-tree', 'trees', 'trees-facet', 'protocol-v1'];
func.dependencies = ['poseidon-libs-v1', 'core-diamond', 'fee-master'];
