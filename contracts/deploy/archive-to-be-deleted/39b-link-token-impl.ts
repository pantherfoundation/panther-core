// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    console.log(deployer);

    const {
        deployments: {deploy},
    } = hre;

    await deploy('MockLinkToken_Implementation', {
        contract: 'MockLinkToken',
        from: deployer,
        args: [deployer],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['link-token-impl'];
func.dependencies = ['check-params', 'deployment-consent'];
