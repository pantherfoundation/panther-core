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

    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('ZAccountsStatusResolver', {
        from: deployer,
        args: [coreDiamond],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['zaccount-status-resolver', 'core', 'protocol-v1'];
func.dependencies = ['core-diamond'];
