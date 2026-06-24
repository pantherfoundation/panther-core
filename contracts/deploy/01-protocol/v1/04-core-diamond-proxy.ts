// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, get},
    } = hre;

    const diamondCutFacet = (await get('DiamondCutFacet')).address;

    await deploy('PantherPoolV1', {
        from: deployer,
        args: [multisig, diamondCutFacet],
        log: true,
        autoMine: true,
        gasPrice: await getGasPrice(hre),
    });
};
export default func;

func.tags = ['core-diamond', 'core', 'protocol-v1', 'protocol-v1-deploy'];
func.dependencies = ['diamond-cut-facet'];
