// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;
    const coreDiamond = (await get('PantherPoolV1')).address;

    const poseidonT3 = (await get('PoseidonT3')).address;

    await deploy('BlacklistedZAccountsIdsRegistry', {
        from: deployer,
        args: [treesDiamond, coreDiamond],
        libraries: {PoseidonT3: poseidonT3},
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = [
    'blacklisted-zaccount-ids-registry',
    'trees',
    'trees-facet',
    'protocol-v1',
];
func.dependencies = ['poseidon-libs-v1', 'trees-diamond', 'core-diamond'];
