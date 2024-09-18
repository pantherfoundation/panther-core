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

    const zAccountVersion = 1;

    const coreDiamond = (await get('PantherPoolV1')).address;
    const treesDiamond = (await get('PantherTrees')).address;
    const feeMaster = (await get('FeeMaster')).address;

    await deploy('ZAccountsRegistration', {
        from: deployer,
        args: [zAccountVersion, coreDiamond, treesDiamond, feeMaster, pzkp],
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['zaccount-registration', 'core', 'core-facet', 'protocol-v1'];
func.dependencies = ['core-diamond', 'trees-diamond', 'fee-master'];
