// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const zAccountsStatusResolver = (await get('ZAccountsStatusResolver'))
        .address;

    await deploy('TestnetZAccountStatusResolver', {
        from: deployer,
        args: [deployer, zAccountsStatusResolver],
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['testnet-zaccount-status-resolver'];
func.dependencies = ['zaccount-status-resolver'];
