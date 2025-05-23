// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const pzkp = await getNamedAccount(hre, 'pzkp');
    const link = await getNamedAccount(hre, 'link');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('TestnetZkpAndLinkDonatory', {
        from: deployer,
        args: [deployer, coreDiamond, link, pzkp],
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['zkp-and-link-donatory'];
func.dependencies = ['core-diamond'];
