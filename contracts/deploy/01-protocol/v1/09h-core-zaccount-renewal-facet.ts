// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;
    const treesDiamond = (await get('PantherTrees')).address;
    const feeMaster = (await get('FeeMaster')).address;

    await deploy('ZAccountsRenewal', {
        from: deployer,
        args: [coreDiamond, treesDiamond, feeMaster, pzkp],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['zaccount-renewal', 'core', 'core-facet', 'protocol-v1'];
func.dependencies = ['core-diamond', 'trees-diamond', 'fee-master'];
