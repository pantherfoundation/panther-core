// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('PantherVerifier', {
        from: deployer,
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['verifier', 'forest', 'zwallet', 'protocol'];
func.dependencies = ['deployment-consent'];
